childProcess = require 'child_process'
path = require 'path'

SSH_BIN_PATH = if App.platform.isWindows
  path.join(App.binPath, 'nitrous-ssh.exe')
else
  path.join(App.binPath, 'nitrous-ssh')

klass = class App.SSH
  constructor: (@container, options) ->
    options ?= {}
    @cmd = options.cmd ? null
    @args = options.args ? []
    @shouldRetryAfterUploadingPublicKey = true
    @onData = options.onData ? null
    @onQuit = options.onQuit ? null
    @onRestarting = options.onRestart ? null
    if options.restartOnExit == null || options.restartOnExit == undefined
      @restartOnExit = true
    else
      @restartOnExit = options.restartOnExit
    @uploadedPublicKey = false

  start: ->
    @stop() if @proc
    @expectingStop = false

    privateKeyPath = App.get 'sshKey.privateKeyPath'
    if App.platform.isWindows
      privateKeyPath = @_getWindowsShortNames(privateKeyPath)

    [host, port] = @container.get('sshUrl').slice(6).split(':')

    sshArgs = [
      '-o', 'UserKnownHostsFile=/dev/null'       # ignore known hosts
      '-o', 'StrictHostKeyChecking=no'           # no host key checking
      '-o', 'PreferredAuthentications=publickey' # pub key authentication only
      '-o', 'LogLevel=FATAL'
      '-p', port
      '-t'
      '-t'
      '-v'
      '-i', privateKeyPath
    ]

    if @args.length > 0
      sshArgs.push.apply sshArgs, @args
    sshArgs.push host

    if @cmd
      sshArgs.push(
        "/bin/bash"
        "-c"
        "echo \"starting..\"; #{@cmd}")
    @proc = childProcess.spawn SSH_BIN_PATH, sshArgs, detached: false

    @_log "Starting SSH connection"
    @proc.stdout.on 'data', (data) => @_processOutput(data)
    @proc.stderr.on 'data', (data) => @_processOutput(data)
    @proc.on 'exit', (code) => @_processDidQuit(code)

  stop: ->
    @expectingStop = true
    @_clearQuitRestarter()
    if @proc
      @proc.stdout.removeAllListeners()
      @proc.stderr.removeAllListeners()
      @proc.kill()
      @proc = undefined

  _processOutput: (data) ->
    formattedData = data.toString('utf8')

    if formattedData.length == 0
      return

    @_log formattedData

    if formattedData.match(/^debug1:/)
      if formattedData.indexOf('Authentication succeeded') != -1
        @shouldRetryAfterUploadingPublicKey = false

    @onData?(formattedData)

  _processDidQuit: (code) ->
    if @expectingStop
      @onQuit?(code)
      return

    if @shouldRetryAfterUploadingPublicKey
      @_log 'Uploading public key'
      @shouldRetryAfterUploadingPublicKey = false
      @_uploadPublicKey (err) =>
        return @_scheduleRetry() if err
        @uploadedPublicKey = true
        @start()
      return

    unless @restartOnExit
      return

    @onRestarting?()
    @_log 'Unexpected quit, restarting'
    @_scheduleRetry()

  _scheduleRetry: (timeout=5000) ->
    @quitRestarter = window.setTimeout(=>
      @quitRestarter = null
      @start()
    , timeout)

  _clearQuitRestarter: ->
    if @quitRestarter
      window.clearTimeout @quitRestarter
      return

  _uploadPublicKey: (cb) ->
    container = @container
    slug = container.get 'slug'
    @_log "Uploading public key..."

    sshKey = App.get('sshKey')
    sshKey.upload container, (err) =>
      cb?(err)

  _getWindowsShortNames: (path)->
    unless path.match(/\s/)
      return path
    cmd = "cmd /c for %A in (\"#{path}\") do @echo %~sA"
    data = childProcess.execSync(cmd)
    data.toString("utf-8").trim()

  _log: (firstMessage, others...) ->
    messages = ["[ssh] #{firstMessage}"]
    messages.concat others
    console.log.apply console, messages
