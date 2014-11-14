app = require 'app'
ipc = require 'ipc'
BrowserWindow = require 'browser-window'
config = require './config'

MixpanelWrapper = require './lib/mixpanel-wrapper'

#require('crash-reporter').start()

root.nitrous =
  loginWindow: null
  mainWindow: null
  mixPanel: null

app.on 'window-all-closed', ->
  nitrous.mixPanel.track 'Quit'
  app.quit()

app.on 'ready', ->
  initMixpanel()

  ipc.on 'logged-in', (event, user) ->
    nitrous.mixPanel.setUser user
    nitrous.mixPanel.track 'Logged In'

    username = user.username
    nitrous.loginWindow.close()
    nitrous.mainWindow = win = initWindow 'main-window/main-window',
      width: 500
      height: 700
      'min-width': 500
      'min-height': 300
      'use-content-size': true
      'auto-hide-menu-bar': false
      data:
        username: username
    win.on 'closed', ->
      nitrous.mainWindow = null
    win.show()
    win.focus()

  ipc.on 'logged-out', (event) ->
    nitrous.mixPanel.track 'Logged Out'
    nitrous.mainWindow.close()
    initLoginWindow()

  ipc.on 'track', (event, arg)->
    nitrous.mixPanel.track arg.eventName, arg.data

  initLoginWindow()

initMixpanel = ->
  nitrous.mixPanel = new MixpanelWrapper 'b578a80392e7a6878d74020c9a5d5b57'
  nitrous.mixPanel.track 'App Started'

initWindow = (js, options={}) ->
  options['web-preferences'] =
    'web-security': false
  options.data = {} unless options.data
  win = new BrowserWindow(options)
  protocol = if config.asar then 'asar:/' else 'file://'
  win.loadUrl(protocol + __dirname + '/index.html')
  win.webContents.on 'did-finish-load', ->
    win.webContents.send 'load-js', js, options.data
  win

initLoginWindow = ->
  nitrous.loginWindow = initWindow 'login-window/login-window',
    show: false
    width: 400
    height: 340
    'use-content-size': true
    'auto-hide-menu-bar': false
  nitrous.loginWindow.on 'closed', ->
    nitrous.loginWindow = null
