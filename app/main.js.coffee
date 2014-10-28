app = require 'app'
ipc = require 'ipc'
BrowserWindow = require 'browser-window'

#require('crash-reporter').start()

mainWindow = null

app.on 'window-all-closed', ->
  if process.platform != 'darwin'
    app.quit()

app.on 'ready', ->
  mainWindow = new BrowserWindow(width: 800, height: 600)

  mainWindow.loadUrl('file://' + __dirname + '/index.html')
  mainWindow.webContents.on 'did-finish-load', ->
    mainWindow.show()
    mainWindow.focus()
    mainWindow.webContents.send 'load-js', 'login-window/login-window'

  ipc.on 'logged-in', (event, token) ->
    console.log 'token is', token

  mainWindow.on 'closed', ->
    mainWindow = null
