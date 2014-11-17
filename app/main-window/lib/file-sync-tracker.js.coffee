App.FileSyncTracker = klass = Em.Object.extend

  loaded: false
  enabledContainers: null
  containers: null

  init: ->
    @_super.apply this, arguments

  isEnabled: (cId)->
    @get('enabledContainers').addObject cId

  isDisabled: (cId)->
    @get('enabledContainers').removeObject cId

  loadEnabledFileSyncContainers: ->
    @loadingFileSyncContents = true
    @set 'enabledContainers', ary = Em.ArrayProxy.create({ content: Ember.A([]) })

    curData = window.localStorage.getItem 'fileSyncEnabled'
    if curData
      deser = JSON.parse curData
      ary.addObjects deser

    @set 'loaded', true
    @loadingFileSyncContents = false
    true

  writeEnabledFileSyncContainers: (->
    return if @loadingFileSyncContents

    ary = @get 'enabledContainers.content'
    if config.debug
      console.log "[main] Writing to fileSyncEnabled, #{ary.length} objects"

    window.localStorage.setItem 'fileSyncEnabled', JSON.stringify(ary)
  ).observes 'enabledContainers.@each'

  restoreFileSync: (->
    return unless @get 'loaded'
    return if @get('fileSyncRestored') || @get('containers') == null || @get('containers.length') == 0

    previousFileSyncs = @get 'enabledContainers'
    console.log "Length: #{@get('containers.length')}"
    @get('containers').forEach (container) =>
      if previousFileSyncs.contains container.id
        if config.debug
          console.log "[main] #{container.id} Restoring file-sync"
        debugger
        container.get('fileSync').set('enabled', true)

    @set 'fileSyncRestored', true
  ).observes 'containers.@each', 'enabledContainers.@each', 'loaded'