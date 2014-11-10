App.MainWindowController = Em.Controller.extend
  actions:
    selectContainer: (container) ->
      App.set 'selectedContainer', container

    showSyncFolder: (fileSync) ->
      fileSync.showSyncFolder()

    openSSHShell: (container) ->
      App.SSHShell.create().startShell container

    openPreview: (container) ->
      App.Preview.previewContainer container

    createHost: ->
      require('shell').openExternal require('./config').host
