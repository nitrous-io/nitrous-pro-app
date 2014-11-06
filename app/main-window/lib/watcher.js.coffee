EventEmitter = require('events').EventEmitter
childProcess = require 'child_process'
path = require 'path'

WATCHER_BIN_PATH = if App.platform.isWindows
  path.join(App.binPath, 'nitrous-watcher.exe')
else
  path.join(App.binPath, 'nitrous-watcher')

SSH_BIN_PATH = if App.platform.isWindows
  path.join(App.binPath, 'nitrous-ssh.exe')
else
  path.join(App.binPath, 'nitrous-ssh')

REMOTE_WATCHER_BIN_PATH = '/nitrous/nitrous-watcher'

startedWatchers = []

klass = class App.Watcher extends EventEmitter
  constructor: (@path, options) ->
    options ?= {}
    @ignore = options.ignore ? ['.unison', '.git', '.svn', '.hg', 'CVS', '.DS_Store', 'Thumbs.db', 'Desktop.ini', 'tmp/sockets', 'tmp/pids', 'tmp/sessions', 'tmp/cache']
    @delay = options.delay ? 100
    @ssh = options.ssh ? false
    @notifyTimeout = null

  _shouldIgnore: (filePath) ->
    components = filePath.split(path.sep)
    for component in components
      continue unless component
      if @ignore.indexOf(component) != -1 || component.indexOf('.unison.') == 0
        return true
    false

  _notify: (filePath) ->
    if @notifyTimeout == null && !@_shouldIgnore(filePath)
      @notifyTimeout = window.setTimeout(=>
        @notifyTimeout = null
        @emit 'change', filePath
      , @delay)

  _clearNotifyTimeout: ->
    if @notifyTimeout
      window.clearTimeout @notifyTimeout
      @notifyTimeout = null

  start: ->
    @stop() if @proc
    @expectingStop = false

    @proc = if @ssh
      privateKeyPath = App.get 'sshKey.privateKeyPath'

      [host, port] = @ssh.slice(6).split(':')

      sshArgs = [
        '-o', 'UserKnownHostsFile=/dev/null'       # ignore known hosts
        '-o', 'StrictHostKeyChecking=no'           # no host key checking
        '-o', 'PreferredAuthentications=publickey' # pub key authentication only
        '-p', port
        '-t'
        '-t'
        '-i', privateKeyPath
        host
        REMOTE_WATCHER_BIN_PATH
        '/home/action/workspace'
      ]
      childProcess.spawn SSH_BIN_PATH, sshArgs, detached: false
    else
      childProcess.spawn WATCHER_BIN_PATH, [@path], detached: false

    startedWatchers.push(this)
    console.log "Starting watcher, remote:", @ssh != null
    @proc.stdout.on 'data', (data) => @_processOutput(data)
    @proc.stderr.on 'data', (data) => @_processOutput(data)
    @proc.on 'exit', (code) => @_processDidQuit(code)

  stop: ->
    @expectingStop = true
    @_clearNotifyTimeout()
    @_clearQuitRestarter()
    if @proc
      @proc.stdout.removeAllListeners()
      @proc.stderr.removeAllListeners()
      @proc.kill()
      @proc = undefined
    index = startedWatchers.indexOf(this)
    startedWatchers.splice(index, 1) if index != -1

  _processOutput: (data) ->
    data = data.toString('utf8')
    if match = data.match /^Change\(.+\): (.+)$/m
      if fileName = match[1]
        filePath = path.join(@path, fileName)
        @_notify(filePath)
    else if data.indexOf('inotify_add_watch') != -1
      window.alert 'Box has exceeded watch amount, please contact support.'

  _processDidQuit: (code) ->
    console.log 'Unexpected quit, restarting'
    @quitRestarter = window.setTimeout(=>
      @quitRestarter = null
      @start()
    , 200)

  _clearQuitRestarter: ->
    if @quitRestarter
      window.clearTimeout @quitRestarter
      return

klass.stopAll = ->
  knownWatchers = startedWatchers.slice 0
  knownWatchers.forEach (watcher) ->
    watcher.stop()
  startedWatchers = []
