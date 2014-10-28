app = require 'app'
ipc = require 'ipc'
BrowserWindow = require 'browser-window'

#require('crash-reporter').start()

root.nitrous =
  loginWindow: null
  mainWindow: null

app.on 'win-all-closed', ->
  if process.platform != 'darwin'
    app.quit()

app.on 'ready', ->
  nitrous.loginWindow = initWindow('login-window/login-window', width: 300, height: 200)
  nitrous.loginWindow.on 'closed', ->
    nitrous.loginWindow = null

  ipc.on 'logged-in', (event) ->
    nitrous.loginWindow.close()
    nitrous.mainWindow = initWindow('main-window/main-window', width: 800, height: 600)
    nitrous.mainWindow.on 'closed', ->
      nitrous.mainWindow = null

initWindow = (js, options={}) ->
  win = new BrowserWindow(options)
  win.loadUrl('file://' + __dirname + '/index.html')
  win.webContents.on 'did-finish-load', ->
    win.show()
    win.focus()
    win.webContents.send 'load-js', js
  win
