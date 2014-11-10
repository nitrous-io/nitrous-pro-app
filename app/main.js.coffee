app = require 'app'
ipc = require 'ipc'
BrowserWindow = require 'browser-window'
config = require './config'

#require('crash-reporter').start()

root.nitrous =
  loginWindow: null
  mainWindow: null

app.on 'window-all-closed', ->
  app.quit()

app.on 'ready', ->
  ipc.on 'logged-in', (event, username) ->
    nitrous.loginWindow.close()
    nitrous.mainWindow = win = initWindow 'main-window/main-window',
      width: 500
      height: 700
      'min-width': 400
      'min-height': 160
      'use-content-size': true
      'auto-hide-menu-bar': false
      data:
        username: username
    win.on 'closed', ->
      nitrous.mainWindow = null
    win.show()
    win.focus()

  ipc.on 'logged-out', (event) ->
    nitrous.mainWindow.close()
    initLoginWindow()

  initLoginWindow()

initWindow = (js, options={}) ->
  options['web-preferences'] =
    'web-security': false
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
