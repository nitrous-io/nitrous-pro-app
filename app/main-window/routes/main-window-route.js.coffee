App.MainWindowRoute = Em.Route.extend
  setupController: (controller) ->
    @_super.apply this, arguments
    App.loadEventsSocket()

    controller.bind()

    App.fetchHosts()
    App.fetchContainers()
    App.fetchSharedContainers()
