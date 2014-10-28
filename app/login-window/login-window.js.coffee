#= require_self
#= require_tree .

window.LoginWindow = Em.Application.extend
  rootElement: '#app'

window.App = LoginWindow.create()

App.Router.map ->
  @route 'login-window', path: '/'
