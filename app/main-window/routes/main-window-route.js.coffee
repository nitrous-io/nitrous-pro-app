App.MainWindowRoute = Em.Route.extend
  setupController: (controller) ->
    @_super.apply this, arguments
    App.fetchHosts()
    App.fetchContainers()
