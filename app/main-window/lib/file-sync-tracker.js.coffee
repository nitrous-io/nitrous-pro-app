config = require './config'
logger = require './lib/logger'

LOCALSTORAGE_KEY = 'fileSyncEnabled'
App.FileSyncTracker = Em.Object.extend

  loaded: false
  enabledContainers: null

  init: ->
    @_super.apply this, arguments

  isEnabled: (cId)->
    @get('enabledContainers').addObject cId

  isDisabled: (cId)->
    @get('enabledContainers').removeObject cId

  flush: ->
    window.localStorage.removeItem 'fileSyncEnabled'

  loadEnabledFileSyncContainers: ->
    @loadingFileSyncContents = true
    @set 'enabledContainers', ary = Em.ArrayProxy.create({ content: Ember.A([]) })

    curData = window.localStorage.getItem LOCALSTORAGE_KEY
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
      @_log "Writing to #{LOCALSTORAGE_KEY}, #{ary.length} objects"

    window.localStorage.setItem LOCALSTORAGE_KEY, JSON.stringify(ary)
  ).observes 'enabledContainers.@each'

  restoreFileSync: (->
    return unless @get 'loaded'
    return if @get('fileSyncRestored') || App.get('containers') == null || App.get('containers') == undefined || App.get('containers.length') == 0

    previousFileSyncs = @get 'enabledContainers'
    App.get('containers').forEach (container) =>
      if previousFileSyncs.contains container.id
        if config.debug
          @_log "#{container.id} Restoring file-sync"
        container.get('fileSync').set('enableWhenReady', true)

    @set 'fileSyncRestored', true
  ).observes 'App.containers.@each', 'enabledContainers.@each', 'loaded'

  _log: (firstMessage, others...) ->
    messages = ["[file-sync-tracker] #{firstMessage}"]
    messages.concat others
    logger.log messages