ajax = require './lib/ajax'

App.Container = klass = Em.Object.extend
  id: null
  cid: null
  name: null
  slug: null
  state: null
  image: null
  hostId: null

  syncEnabled: false

  displayName: (->
    @get('name') || @get('slug')
  ).property 'name', 'slug'

  selected: (->
    App.get('selectedContainer') == this
  ).property 'App.selectedContainer'

klass.reopenClass
  fetch: ->
    containers = Em.ArrayProxy.create()
    ajax(
      type: 'GET'
      url: '/api/v0/containers'
    ).then (res) ->
      if Em.isArray(res.containers)
        containers.set 'content', res.containers.map (c) ->
          App.Container.create
            id: c.id
            cid: c.cid
            name: c.name
            slug: c.slug
            state: c.state
            image: c.image
            hostId: c.host_id
    , (jqxhr) ->
      json = jqxhr.responseJSON
      window.alert(json.error_description || json.error || "Failed to load containers (#{jqxhr.statusText})")
    containers
