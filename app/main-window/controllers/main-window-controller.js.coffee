App.MainWindowController = Em.Controller.extend
  actions:
    selectContainer: (container) ->
      App.set 'selectedContainer', container
