App.MainWindowController = Em.Controller.extend
  actions:
    selectContainer: (container) ->
      App.track 'Select Container',
        container_id: container.id
      App.set 'selectedContainerId', container.id

    showSyncFolder: (fileSync) ->
      App.track 'Click Open Folder',
        container_id: fileSync.container.id
      fileSync.showSyncFolder()

    openSSHShell: (container) ->
      App.track 'Click Shell',
        container_id: container.id
      App.SSHShell.create().startShell container

    openPreview: (container) ->
      App.track 'Click Preview',
        container_id: container.id
      App.Preview.previewContainer container

    createHost: ->
      App.track 'Click Create Application'
      require('shell').openExternal require('./config').host
