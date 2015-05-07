#= require_self
#= require ./app

fs = require 'fs'
path = require 'path'
childProcess = require 'child_process'
ipc = require 'ipc'
config = require './config'
logger = require './lib/logger'

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

  fileSyncTracker: null

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

  fetchHosts: ->
    @set 'hosts', App.Host.fetch()

  fetchContainers: ->
    if @get('containers') == null
      return @set 'containers', App.Container.fetch()

    @_log "Containers refreshing"
    @refreshingContainers = true
    existingContainers = @get 'containers'
    removeable = existingContainers.content.copy()
    App.Container.fetchEachRaw (cJson) =>
      removeable = removeable.rejectBy 'id', cJson.id
      existingContainer = existingContainers.findBy('id', cJson.id)
      if existingContainer
        @_log "Updating existing container [#{existingContainer.get('id')}]"
        wasSyncing = existingContainer.get 'fileSync.enabled'
        existingContainer.applyFromJsonObject cJson
        existingContainer.refreshConfig()
      else
        newCon = App.Container.create()
        newCon.applyFromJsonObject cJson
        newCon.get 'config'
        newCon
        @_log "Adding new container [#{newCon.get('id')}]"
        existingContainers.addObject newCon
    , () ->
      removeable.forEach (c)->
        @_log "Removing [#{c.id}]"
        c.set('fileSync.enabled', false)
      existingContainers.removeObjects removeable
      @refreshingContainers = false

  _log: (firstMessage, others...) ->
    messages = ["[main-window] #{firstMessage}"]
    messages.concat others
    logger.log messages

window.App = klass.create()

$(window).on 'online', ->
  ipc.send 'online'
  App.set 'online', true
  App.loadEventsSocket()

$(window).on 'offline', ->
  ipc.send 'offline'
  App.set 'online', false
  App.unloadEventsSocket()

fs.mkdirSync(App.dataPath, '0755') unless fs.existsSync(App.dataPath)
fs.mkdirSync(App.usersDataPath, '0755') unless fs.existsSync(App.usersDataPath)
fs.mkdirSync(App.userDataPath, '0755') unless fs.existsSync(App.userDataPath)

logger.setLogPath(App.dataPath)

App.on 'app-did-load', ->
  App.set 'fileSyncTracker', tracker = App.FileSyncTracker.create()
  tracker.loadEnabledFileSyncContainers()

  App.set 'sshKey', sshKey = App.SSHKey.create()
  sshKey.load()

  App.set 'updater', updater = App.Updater.create()
  updater.startSchedule()

  # load main window route
  App.Router.map ->
    @route 'main-window', path: '/'

App.on 'log-out', ->
  App.get('fileSyncTracker').flush()
  App.set('fileSyncTracker.loaded', false)
  window.localStorage.removeItem 'access-token'
  App.get('sshKey')?.deleteKeys()
  App.Watcher.stopAll()
  App.SSHPortForwarder.stopAll()
  ipc.send 'logged-out'
  App.unloadEventsSocket()

window.onbeforeunload = ->
  App.Watcher.stopAll()
  App.SSHPortForwarder.stopAll()
  return true
