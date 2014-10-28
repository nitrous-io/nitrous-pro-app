#= require_self
#= require_tree .

window.MainWindow = Em.Application.extend
  rootElement: '#app'

window.App = MainWindow.create()

App.Router.map ->
  @route 'main-window', path: '/'
