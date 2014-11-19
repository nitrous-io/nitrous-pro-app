childProcess = require 'child_process'
fs = require 'fs'
path = require 'path'

UNISON_BIN_PATH = if App.platform.isWindows
  path.join(App.binPath, 'nitrous-unison.exe')
else
  path.join(App.binPath, 'nitrous-unison.sh')

SSH_BIN_PATH = if App.platform.isWindows
  path.join(App.binPath, 'nitrous-ssh.exe')
else
  path.join(App.binPath, 'nitrous-ssh')

SHORTNAME_BIN_PATH = path.join(App.binPath, 'shortname.bat')

IGNORE_LIST = 'Name {.unison,.git,.svn,.hg,CVS,.DS_Store,.AppleDouble,.LSOverride,.Spotlight-V100,.Trashes,*.sock,*.pid,*.sw?,._*,*~}'
IGNORE_FOLDERS = 'Path {*/tmp/sessions,*/tmp/cache,*/tmp/pids,*/tmp/sockets}'

App.Unison = klass = Em.Object.extend
  container: null
  syncPath: null

  syncing: false
  process: null

  lastErrorMessage: null
  malformedPattern: null
  transferCount: 0
  retrySchedule: null

  shouldAbort: false
  shouldSyncAgain: false
  shouldIgnoreArchives: false
  shouldIgnoreLocks: false
  shouldRetryWithDelay: null
  shouldRetryAfterUploadingPublicKey: false

  onRetry: null
  onRestored: null
  onPatternError: null

  syncOnly: null

  ignoreList: null

  abort: ->
    @_log 'aborting sync...'
    if @get 'syncing'
      @set 'shouldAbort', true
    if schedule = @get 'retrySchedule'
      Em.run.cancel(schedule)

    @setProperties
      shouldSyncAgain: false
      shouldIgnoreArchives: false
      shouldIgnoreLocks: false
      shouldRetryWithDelay: null
      shouldRetryAfterUploadingPublicKey: false

  sync: (cb) ->
    if @get 'syncing'
      @_log 'sync requested while syncing, will run sync again later'
      @set 'shouldSyncAgain', true
      return # don't invoke callback

    @set 'syncing', true

    sshUrl = @get 'container.sshUrl'
    syncPath = @get 'syncPath'
    remotePath = "#{sshUrl}/workspace"

    nullFile = if App.platform.isWindows
      'NUL'
    else
      '/dev/null'

    invokeUnison = (privateKeyPath) =>
      sshArgs = [
        '-o', "UserKnownHostsFile=#{nullFile}"     # ignore known hosts
        '-o', 'StrictHostKeyChecking=no'           # no host key checking
        '-o', 'PreferredAuthentications=publickey' # pub key authentication only
        '-i', privateKeyPath
      ]

      args = [
        syncPath
        remotePath
        '-ui', 'text'
        '-auto'  # auto accept default actions
        '-batch' # ask no questions
        '-perms=777'  # sync all permissions
        '-confirmbigdel=false' # don't ask about whole replica deletes
        '-log=false'  # don't log
        '-rsrc=false' # don't sync resource fork
        '-sshargs', sshArgs.join ' '
        '-ignore', IGNORE_LIST
        '-ignore', IGNORE_FOLDERS
        '-ignorecase', 'true' # case-insensitive
        '-prefer', remotePath
        '-terse' # reduce output
        '-servercmd', '/nitrous/nitrous-unison'
        '-sshcmd', SSH_BIN_PATH
      ]

      if syncOnly = @get 'syncOnly'
        args.push '-ignore', 'Name ?*', '-ignorenot', syncOnly

      if (ignoreList = @get('ignoreList')) != null
        ignoreList.forEach (ignore) =>
          @_log "Ingoring #{ignore}"
          args.push '-ignore', ignore

      # place archives file in syncPath/.unison
      unisonArchivesPath = path.join(syncPath, '.unison')
      env = $.extend({}, process.env)
      env.UNISON = unisonArchivesPath

      if App.platform.isWindows
        env.HOME = App.homePath
        env.Path = App.binPath + ';' + process.env.Path
        fs.mkdir unisonArchivesPath, '0755', (err) ->
          childProcess.execFile 'attrib.exe', ['+h', unisonArchivesPath]

      options =
        cwd: App.homePath
        detached: false
        env: env

      fs.exists unisonArchivesPath, (archiveExists) =>
        if !archiveExists || @get 'shouldIgnoreArchives'
          @set 'shouldIgnoreArchives', false
          args.push '-ignorearchives'

        if @get 'shouldIgnoreLocks'
          @set 'shouldIgnoreLocks', false
          args.push '-ignorelocks'

        @_log 'syncing...'

        proc = if App.platform.isWindows
          childProcess.spawn UNISON_BIN_PATH, args, options
        else
          args.unshift UNISON_BIN_PATH
          childProcess.spawn '/bin/bash', args, options

        @set 'process', proc
        proc.stdout.on 'data', (data) => @handleProcessOutput(data)
        proc.stderr.on 'data', (data) => @handleProcessOutput(data)
        proc.on 'exit', (code) => @processDidExit(code, cb)

    privateKeyPath = App.get 'sshKey.privateKeyPath'

    if App.platform.isWindows
      childProcess.execFile SHORTNAME_BIN_PATH, [privateKeyPath], (err, stdout, stderr) ->
        console.log stdout
        invokeUnison(stdout)
    else
      invokeUnison(privateKeyPath.replace(/\ /g, '\\ '))

  handleProcessOutput: (data) ->
    data = data.toString('utf8')
    @_log data

    if @get 'shouldAbort'
      return @set 'shouldAbort', false

    if errorMessage = data.match(/[Ee]rror:\s*(.+)$/m)?[1]?.toLowerCase()
      if errorMessage.indexOf('warning: inconsistent state.') != -1 ||
         errorMessage.indexOf('on-disk archives are not identical') != -1
        @set 'lastErrorMessage', 'Inconsistent state'
        @set 'shouldIgnoreArchives', true
        @set 'shouldRetryWithDelay', 200
      else if errorMessage.indexOf('warning: the archives are locked.') != -1
        @set 'lastErrorMessage', 'Archives are locked'
        @set 'shouldIgnoreLocks', true
        @set 'shouldRetryWithDelay', 200
      else if errorMessage.indexOf('lost connection with the server') != -1
        # determine if we need to correct an SSH issue
        @_log 'Lost connection'
        @set 'lastErrorMessage', 'Connection failed'
        @set 'shouldRetryWithDelay', 5000
      else if patErr = data.match(/Malformed\s*pattern:\s*(.+)/)?[1]?.toLowerCase()
        patErr = patErr.replace(/(^"|"$)/g, "")
        @set 'malformedPattern', patErr
      else
        @set 'lastErrorMessage', errorMessage
        @set 'shouldRetryWithDelay', 5000
    if data.indexOf('Uncaught exception Sys_blocked_io') != -1
      @set 'shouldRetryWithDelay', 200
    if data.indexOf('Permission denied (') != -1
      @_log 'ssh permission denied'
      @set 'shouldRetryAfterUploadingPublicKey', true
    else if transferCount = data.match(/Synchronization complete at .+ \(([\d,]+) items? transferred/)?[1]
      @set 'transferCount', window.parseInt(transferCount.replace(/,/g, ''), 10)

  processDidExit: (code, cb) ->
    @_log "sync process exited with code #{code}"
    @set 'process', null
    @set 'syncing', false

    if @get 'shouldRetryAfterUploadingPublicKey'
      @set 'shouldRetryAfterUploadingPublicKey', false
      @uploadPublicKey (err) =>
        return @scheduleRetry(cb, 5000) if err
        @sync(cb)
      return

    if pattErr = @get 'malformedPattern'
      return @get('onPatternError')?(pattErr)

    if @get 'shouldAbort'
      return @set 'shouldAbort', false

    retryDelay = @get 'shouldRetryWithDelay'
    @set 'shouldRetryWithDelay', null

    if typeof retryDelay == 'number' || code == 3
      @set('lastErrorMessage', 'Unknown error') unless @get 'lastErrorMessage'
      return @scheduleRetry(cb, retryDelay)

    if transferCount = @get 'transferCount'
      @_log "#{transferCount} item#{if transferCount > 1 then 's' else ''} transferred"

    if @badState
      @badState = false
      @get('onRestored')?()

    if @get 'shouldSyncAgain'
      @set 'shouldSyncAgain', false
      @sync(cb)
    else
      cb?()

  scheduleRetry: (cb, delay) ->
    @badState = true
    @get('onRetry')?()
    if @get('retrySchedule') == null
      @set 'retrySchedule', Em.run.later(=>
        @set 'retrySchedule', null
        @_log "retrying sync..."
        @sync(cb)
      , delay)

  uploadPublicKey: (cb) ->
    container = @get 'container'
    slug = container.get 'slug'
    @_log "Uploading public key..."

    sshKey = App.get('sshKey')
    sshKey.upload container, (err) =>
      cb?(err)

  parseIgnoreContents: (string) ->
    ignoreList=[]
    string.split(/\n/).forEach (l)=>
      return if l.length == 0 || l[0] == "#"
      pathMode = false
      if l[0] == "/"
        pathMode = true
        l = l.substr 1

      if l.indexOf("**") != -1
        l = l.replace /\./g, "\\."
        l = l.replace /\*/g, ".*"
        ignoreList.push "Regex #{l}"
      else
        mode = if pathMode
          "Path"
        else
          "Name"
        ignoreList.push "#{mode} #{l}"
    @set 'ignoreList', ignoreList

  _log: (firstMessage, others...) ->
    messages = ["[unison] #{@get('container.slug')}: #{firstMessage}"]
    messages.concat others
    console.log.apply console, messages

klass.reopenClass
  killAll: (cb) ->
    App.killAll 'nitrous-unison', cb
