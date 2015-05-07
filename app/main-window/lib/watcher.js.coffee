EventEmitter = require('events').EventEmitter
childProcess = require 'child_process'
path = require 'path'
logger = require './lib/logger'

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
    @ssh = if options.container
      new App.SSH(options.container,
        cmd: "killall nitrous-watcher; /nitrous/nitrous-watcher /home/nitrous/code"
        onData: (data)=>
          @_processOutput(data)
        onRestarting: ()=>
          @_handleWatcherRestarting()
      )
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

    if @ssh
      @ssh.start()
    else
      @proc = childProcess.spawn WATCHER_BIN_PATH, [@path], detached: false

      @_log "Starting local watcher"
      @proc.stdout.on 'data', (data) => @_processOutput(data)
      @proc.stderr.on 'data', (data) => @_processOutput(data)
      @proc.on 'exit', (code) => @_processDidQuit(code)

    if @badState
      @badState = false
      @emit 'watcherRestored', this

    startedWatchers.push(this)

  stop: ->
    @expectingStop = true
    @_clearNotifyTimeout()
    @_clearQuitRestarter()

    if @ssh
      @ssh.stop()
    else if @proc
      @proc.stdout.removeAllListeners()
      @proc.stderr.removeAllListeners()
      @proc.kill()
      @proc = undefined

    index = startedWatchers.indexOf(this)
    startedWatchers.splice(index, 1) if index != -1

  _processOutput: (data) ->
    data = data.toString('utf8')
    @_log data
    if match = data.match /^Change\(.+\): (.+)$/m
      if fileName = match[1]
        filePath = path.join(@path, fileName)
        @_notify(filePath)
    else if data.indexOf('inotify_add_watch') != -1
      window.alert 'Box has exceeded watch amount, please contact support.'
    else if @badState
      if data.indexOf('Ready to watch') != -1
        @badState = false
        @emit 'watcherRestored', this

  _processDidQuit: (code) ->
    return if @expectingStop

    @_log 'Unexpected quit, restarting'
    @_handleWatcherRestarting()
    @quitRestarter = window.setTimeout(=>
      @quitRestarter = null
      @start()
    , 100)

  _handleWatcherRestarting: ->
    @badState = true
    @emit 'watcherRestarting', this

  _clearQuitRestarter: ->
    if @quitRestarter
      window.clearTimeout @quitRestarter
      return

  _log: (firstMessage, others...) ->
    messages = ["[watcher] #{firstMessage}"]
    messages.concat others

    cleansed = []
    messages.forEach (ln)=>
      ln.split(/\r?\n/).forEach (nl)=>
        if cleansed[cleansed.length-1] != nl
          cleansed.push nl

    if @_arrayEqual(@lastLog, cleansed)
      return
    @lastLog = cleansed # prevent constant hits to the same file spewing onto logs
    logger.log cleansed

  _getWindowsShortNames: (path)->
    unless path.match(/\s/)
      return path
    cmd = "cmd /c for %A in (\"#{path}\") do @echo %~sA"
    data = childProcess.execSync(cmd)
    data.toString("utf-8").trim()

  _arrayEqual: (a, b) ->
    return false unless a && b
    a.length is b.length and a.every (elem, i) -> elem is b[i]

klass.stopAll = ->
  knownWatchers = startedWatchers.slice 0
  knownWatchers.forEach (watcher) ->
    watcher.stop()
  startedWatchers = []
