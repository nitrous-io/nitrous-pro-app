#= require_self
#= require_tree .

window.MainWindow = Em.Application.extend
  rootElement: '#app'
  hosts: null
  containers: null

window.App = MainWindow.create()

App.Router.map ->
  @route 'main-window', path: '/'
