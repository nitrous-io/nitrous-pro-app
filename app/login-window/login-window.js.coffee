#= require_self
#= require_tree .

os = require 'os'

platform =
  isWindows: os.type() == 'Windows_NT'
  isMac: os.type() == 'Darwin'
  isLinux: os.type() == 'Linux'

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
