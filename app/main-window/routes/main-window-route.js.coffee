App.MainWindowRoute = Em.Route.extend
  setupController: (controller) ->
    @_super.apply this, arguments
    App.set 'hosts', App.Host.fetch()
    App.set 'containers', App.Container.fetch()
