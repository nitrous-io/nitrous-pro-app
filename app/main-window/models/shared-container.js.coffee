ajax = require './lib/ajax'

App.SharedContainer = klass = App.Container.extend
  _host: null

  canEdit: false

  loadConfig: ->
    @ajax('GET', 'config').then (json) =>
      @setConfig(json.config)

  applyFromJsonObject: (c)->
    @_super.apply this, arguments
    debugger
    @set '_host', c.host

  host: (->
    return unless @get("_host")
    App.Host.fromJSON(@get("_host"))
  ).property '_host'

klass.reopenClass
  fetchEachRaw: (eachFunc, cb) ->
    sharedContainers = Em.ArrayProxy.create()
    ajax(
      type: 'GET'
      url: '/api/v0/shared_containers'
    ).then (res) ->
      if Em.isArray(res.containers)
        sharedContainers.set 'content', res.containers.map (c) ->
          eachFunc(c)
      cb?(sharedContainers)
    , (jqxhr) ->
      json = jqxhr.responseJSON
      window.alert(json?.error_description || json?.error || "Failed to load shared containers (#{jqxhr.statusText})")
    sharedContainers

  fetch: (cb) ->
    @fetchEachRaw (c) ->
      container = App.SharedContainer.create()
      container.applyFromJsonObject c
      container.get 'config'
      container
    , (sharedContainers) ->
      cb?(sharedContainers)