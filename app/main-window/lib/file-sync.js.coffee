fs = require 'fs'
path = require 'path'
shell = require 'shell'

NITROUS_FOLDER_PATH = path.join(App.homePath, 'Nitrous')

App.FileSync = klass = Em.Object.extend
  container: null
  state: null
  watcher: null
  remoteWatcher: null
  started: false
  enabled: false
  unison: null

  init: ->
    @_super.apply this, arguments
    Em.run.next =>
      @controlWatcher()

  syncPath: (->
    if slug = @get 'container.slug'
      path.join(NITROUS_FOLDER_PATH, slug)
  ).property 'container.slug'

  controlWatcher: (->
    if @get('enabled') && @get('container.state') == 'running' && App.get('online') && @get('syncPath') && @get('container.sshUrl')
      @startWatcher()
    else
      @stopWatcher()
  ).observes 'enabled', 'container.state', 'App.online', 'syncPath', 'container.sshUrl'

  showSyncFolder: ->
    if App.platform.isMac || App.platform.isWindows
      shell.openExternal "file://#{@get 'syncPath'}"
    else
      shell.openItem @get('syncPath')

  startWatcher: (cb) ->
    return if @get 'started'
    @set 'started', true

    @expectedUnisonAbort = false

    syncPath = @get 'syncPath'
    container = @get 'container'
    slug = container.get 'slug'
    sshUrl = container.get 'sshUrl'

    # make nitrous folder
    fs.mkdir NITROUS_FOLDER_PATH, '0755', (err) =>
      return cb?(err) if err && err.code != 'EEXIST'
      fs.mkdir syncPath, '0755', (err) =>
        return cb?(err) if err && err.code != 'EEXIST'
        # initialize watcher
        @set 'unison', App.Unison.create(container: container, syncPath: syncPath)
        @set 'watcher', watcher = new App.Watcher(syncPath)
        watcher.on 'change', (change) =>
          @_log "detected local fs change at #{change}"
          @performSync()
        @set 'remoteWatcher', remoteWatcher = new App.Watcher('~/workspace', ssh: sshUrl)
        remoteWatcher.on 'change', (change) =>
          @_log "detected remote fs change at #{change}"
          @performSync()
        # perform initial sync
        @kickOffInitialSync()
        cb?()

  stopWatcher: ->
    if watcher = @get 'watcher'
      @_log 'stopping watcher...'
      watcher.stop()
      @set 'watcher', null
    if remoteWatcher = @get 'remoteWatcher'
      @_log 'stopping remote watcher...'
      remoteWatcher.stop()
      @set 'remoteWatcher', null
    if unison = @get 'unison'
      @expectedUnisonAbort = true
      unison.abort()
      @set 'unison', null
    @set 'started', false
    @set 'enabled', false

  kickOffInitialSync: ->
    @performSync =>
      # initial sync succeeded, fire up watchers
      return unless @get 'started' # if sync is disabled before first sync is completed
      @_log 'starting watcher...'
      @get('watcher').start()
      @_log 'starting remote watcher...'
      @get('remoteWatcher').start()

  _log: (firstMessage, others...) ->
    messages = ["[file-sync] #{@get('container.slug')}: #{firstMessage}"]
    messages.concat others
    console.log.apply console, messages

  performSync: (cb) ->
    return unless @get 'started'
    if unison = @get 'unison'
      unison.sync(cb)
    else
      cb?()
