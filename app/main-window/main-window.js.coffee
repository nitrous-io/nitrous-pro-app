#= require_self
#= require_tree .

os = require 'os'
fs = require 'fs'
path = require 'path'
childProcess = require 'child_process'

platform =
  isWindows: os.type() == 'Windows_NT'
  isMac: os.type() == 'Darwin'
  isLinux: os.type() == 'Linux'

homePath = if platform.isWindows
  process.env.HOMEDRIVE + process.env.HOMEPATH
else
  process.env.HOME

window.MainWindow = klass = Em.Application.extend
  rootElement: '#app'

  username: DATA.username
  hosts: null
  containers: null
  selectedContainer: null

  online: navigator.onLine
  offline: Em.computed.not 'online'

  platform: platform

  homePath: homePath

  binPath: if platform.isWindows
    path.join(__dirname, 'bin', 'win')
  else
    path.join(__dirname, 'bin', 'osx')

  dataPath: if platform.isWindows
    path.join(process.env.APPDATA, 'Nitrous')
  else if platform.isMac
    path.join(homePath, 'Library', 'Application Support', 'Nitrous')
  else
    path.join(homePath, '.nitrous')

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

fs.mkdirSync(App.dataPath, '0755') unless fs.existsSync(App.dataPath)

App.Router.map ->
  @route 'main-window', path: '/'
