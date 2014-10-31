#= require_self
#= require_tree .

os = require 'os'
path = require 'path'
childProcess = require 'child_process'

platform =
  isWindows: os.type() == 'Windows_NT'
  isMac: os.type() == 'Darwin'

window.MainWindow = klass = Em.Application.extend
  rootElement: '#app'
  hosts: null
  containers: null
  selectedContainer: null

  online: navigator.onLine
  offline: Em.computed.not 'online'

  platform: platform

  homePath: if platform.isWindows
    process.env.HOMEDRIVE + process.env.HOMEPATH
  else
    process.env.HOME

  binPath: if platform.isWindows
    path.join(__dirname, 'bin', 'win')
  else
    path.join(__dirname, 'bin', 'osx')

  killAll: (procName, cb) ->
    if platform.isWindows
      childProcess.execFile 'taskkill.exe', ['/IM', procName + '.exe', '/F'], {}, cb
    else
      childProcess.execFile '/usr/bin/killall', ['-9', procName], {}, cb

window.App = klass.create()

$(window).on 'online', ->
  App.set 'online', true

$(window).on 'offline', ->
  App.set 'online', false

App.Router.map ->
  @route 'main-window', path: '/'
