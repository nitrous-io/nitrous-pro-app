app = require 'app'
ipc = require 'ipc'
BrowserWindow = require 'browser-window'

#require('crash-reporter').start()

root.nitrous =
  loginWindow: null
  mainWindow: null

app.on 'win-all-closed', ->
  app.quit()

app.on 'ready', ->
  ipc.on 'logged-in', (event, username) ->
    nitrous.loginWindow.close()
    nitrous.mainWindow = initWindow 'main-window/main-window',
      width: 800
      height: 600
      'use-content-size': true
      'auto-hide-menu-bar': false
      data:
        username: username
    nitrous.mainWindow.on 'closed', ->
      nitrous.mainWindow = null

  ipc.on 'logged-out', (event) ->
    nitrous.mainWindow.close()
    initLoginWindow()

  initLoginWindow()

initWindow = (js, options={}) ->
  win = new BrowserWindow(options)
  win.loadUrl('file://' + __dirname + '/index.html')
  win.webContents.on 'did-finish-load', ->
    win.webContents.send 'load-js', js, options.data
    win.show()
    win.focus()
  win

initLoginWindow = ->
  nitrous.loginWindow = initWindow 'login-window/login-window',
    width: 300
    height: 200
    'use-content-size': true
    'auto-hide-menu-bar': false
  nitrous.loginWindow.on 'closed', ->
    nitrous.loginWindow = null
