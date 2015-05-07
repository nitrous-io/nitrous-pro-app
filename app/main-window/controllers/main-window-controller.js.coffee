App.MainWindowController = Em.Controller.extend
  showAddPortEntry: false
  addPort: null
  selectedPort: null

  portPairs: (->
    pairs = App.get('selectedContainer.portForwarder.portPairs')
    return [] unless pairs
    pairs.map (pair)=>
      if @get('selectedPort') == pair.local
        pair.selected = true
      else
        pair.selected = false

      if pair.local == pair.remote
        pair.display = pair.local
      pair
  ).property 'selectedPort', 'App.selectedContainer.portForwarder.portPairs'

  showPlaceholder: (->
    return false if @get 'showAddPortEntry'
    @get('portPairs.length') == 0
  ).property 'showAddPortEntry', 'portPairs'

  bind: ->
    window.onkeydown = (event)=>
      keyID = event.keyCode
      if keyID == 8
        if event.target?.nodeName?.toLowerCase() == "input" || event.srcElement?.nodeName?.toLowerCase() == "input"
          return
        event.preventDefault()
        @send 'removeSelectedPort'

  actions:
    removeSelectedPort: ->
      pairs = @get('portPairs')
      if p = @get('selectedPort')

        nextPort = null
        seenNext = false
        pairs.forEach (pair)=>
          if pair.local == p
            seenNext = true
          else if seenNext
            nextPort = pair.local
            seenNext = false

        unless nextPort
          nextPort = pairs[pairs.length - 2]?.local
        App.get('selectedContainer.portForwarder').removePort(p)
        @set 'selectedPort', nextPort
        @set 'showAddPortEntry', false
        @set 'addPort', null

    showAddPort: ->
      @set 'showAddPortEntry', true
      @set 'selectedPort', null
      Em.run.next ->
        $(".selected li.input form input").focus()

    addPortLostFocus: ->
      if @get 'addPort'
        @send 'didAddPort'
      else
        @set 'showAddPortEntry', false

    selectPort: (pair)->
      @set 'selectedPort', pair.local

    didAddPort: ->
      if p = @get('addPort')
        App.get('selectedContainer.portForwarder').addPort(p)
        @set 'showAddPortEntry', false
        @set 'addPort', null

    selectContainer: (container) ->
      @set 'showAddPortEntry', false
      @set 'addPort', null
      @set 'selectedPort', null

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
