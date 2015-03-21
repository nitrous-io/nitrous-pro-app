App.MainWindowRoute = Em.Route.extend
  setupController: (controller) ->
    @_super.apply this, arguments
    App.loadEventsSocket()

    App.fetchHosts()
    App.fetchContainers()
