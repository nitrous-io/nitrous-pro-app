#= require_self
#= require_tree .

platform =
  isWindows: process.platform == 'win32'
  isMac: process.platform == 'darwin'
  isLinux: process.platform == 'linux'

window.LoginWindow = Em.Application.extend
  rootElement: '#app'

  online: navigator.onLine
  offline: Em.computed.not 'online'

  platform: platform

window.App = LoginWindow.create()

$(window).on 'online', ->
  App.set 'online', true

$(window).on 'offline', ->
  App.set 'online', false

App.Router.map ->
  @route 'login-window', path: '/'
