#= require_self
#= require ./app

fs = require 'fs'
path = require 'path'
childProcess = require 'child_process'
ipc = require 'ipc'
config = require './config'

remote = require 'remote'
mainApp = remote.require 'app'

platform =
  isWindows: process.platform == 'win32'
  isMac: process.platform == 'darwin'
  isLinux: process.platform == 'linux'

username = DATA.username

homePath = if platform.isWindows
  process.env.HOMEDRIVE + process.env.HOMEPATH
else
  process.env.HOME

binPath = if platform.isWindows
  path.join(config.resPath, 'bin', 'win')
else if platform.isMac
  path.join(config.resPath, 'bin', 'osx')
else
  path.join(config.resPath, 'bin', 'linux')

dataPath = if platform.isWindows
  path.join(process.env.APPDATA, 'Nitrous')
else if platform.isMac
  path.join(homePath, 'Library', 'Application Support', 'Nitrous')
else
  path.join(homePath, '.nitrous')

usersDataPath = path.join(dataPath, "Users")

window.MainWindow = klass = Em.Application.extend Em.Evented,
  rootElement: '#app'

  username: username
  sshKey: null

  hosts: null
  containers: null
  selectedContainerId: null

  online: navigator.onLine
  offline: Em.computed.not 'online'

  platform: platform

  homePath: homePath
  binPath: binPath
  dataPath: dataPath
  usersDataPath: usersDataPath
  userDataPath: path.join(usersDataPath, username)

  appPath: config.appPath

  selectedContainer: (->
    App.get('containers').findBy 'id', @get('selectedContainerId')
  ).property 'selectedContainerId', 'containers.@each'

  quit: ->
    mainApp.quit()

  killAll: (procName, cb) ->
    if platform.isWindows
      childProcess.execFile 'taskkill.exe', ['/IM', procName + '.exe', '/F'], {}, cb
    else
      childProcess.execFile '/usr/bin/killall', ['-9', procName], {}, cb

  loadEventsSocket: ->
    @unloadEventsSocket()
    App.set 'eventsSocket', eventsSocket = App.EventsSocket.create()
    eventsSocket.connect()

  unloadEventsSocket: ->
    return unless App.get 'eventsSocket'
    App.get('eventsSocket').disconnect()
    App.set('eventsSocket', null)

  track: (event_name, data)->
    ipc.send 'track',
      eventName:event_name
      data: data

window.App = klass.create()

$(window).on 'online', ->
  App.set 'online', true
  App.loadEventsSocket()

$(window).on 'offline', ->
  App.set 'online', false
  App.unloadEventsSocket()

fs.mkdirSync(App.dataPath, '0755') unless fs.existsSync(App.dataPath)
fs.mkdirSync(App.usersDataPath, '0755') unless fs.existsSync(App.usersDataPath)
fs.mkdirSync(App.userDataPath, '0755') unless fs.existsSync(App.userDataPath)

App.on 'app-did-load', ->
  App.set 'sshKey', sshKey = App.SSHKey.create()
  sshKey.load()

  App.set 'updater', updater = App.Updater.create()
  updater.startSchedule()

  # load main window route
  App.Router.map ->
    @route 'main-window', path: '/'

  App.loadEventsSocket()

App.on 'log-out', ->
  window.localStorage.removeItem 'access-token'
  App.get('sshKey')?.deleteKeys()
  App.Watcher.stopAll()
  ipc.send 'logged-out'
  App.unloadEventsSocket()

window.onbeforeunload = ->
  App.Watcher.stopAll()
  return true
