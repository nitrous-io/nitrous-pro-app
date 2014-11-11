#= require_self
#= require_tree .

config = require './config'

platform =
  isWindows: process.platform == 'win32'
  isMac: process.platform == 'darwin'
  isLinux: process.platform == 'linux'

window.LoginWindow = Em.Application.extend
  rootElement: '#app'

  online: navigator.onLine
  offline: Em.computed.not 'online'

  platform: platform

  curVersion: config.version

window.App = LoginWindow.create()

$(window).on 'online', ->
  App.set 'online', true

$(window).on 'offline', ->
  App.set 'online', false

App.Router.map ->
  @route 'login-window', path: '/'
