#= require_self
#= require ./app

os = require 'os'
fs = require 'fs'
path = require 'path'
childProcess = require 'child_process'

platform =
  isWindows: os.type() == 'Windows_NT'
  isMac: os.type() == 'Darwin'
  isLinux: os.type() == 'Linux'

username = DATA.username

homePath = if platform.isWindows
  process.env.HOMEDRIVE + process.env.HOMEPATH
else
  process.env.HOME

binPath = if platform.isWindows
  path.join(__dirname, 'bin', 'win')
else
  path.join(__dirname, 'bin', 'osx')

dataPath = if platform.isWindows
  path.join(process.env.APPDATA, 'Nitrous')
else if platform.isMac
  path.join(homePath, 'Library', 'Application Support', 'Nitrous')
else
  path.join(homePath, '.nitrous')

window.MainWindow = klass = Em.Application.extend Em.Evented,
  rootElement: '#app'

  username: username
  sshKey: null

  hosts: null
  containers: null
  selectedContainer: null

  online: navigator.onLine
  offline: Em.computed.not 'online'

  platform: platform

  homePath: homePath
  binPath: binPath
  dataPath: dataPath
  userDataPath: path.join(dataPath, username)

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
fs.mkdirSync(App.userDataPath, '0755') unless fs.existsSync(App.userDataPath)

App.Router.map ->
  @route 'main-window', path: '/'

App.on 'app-did-load', ->
  App.set 'sshKey', sshKey = App.SSHKey.create()
  sshKey.load()
