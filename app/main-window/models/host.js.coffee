ajax = require './lib/ajax'

App.Host = klass = Em.Object.extend
  id: null
  name: null
  slug: null
  state: null

  hostname: null
  freighterdPort: null
  proxyHostname: null
  ipAddress: null

  containers: (->
    if containers = App.get('containers')
      containers.filterBy 'hostId', @get('id')
  ).property 'App.containers.@each', 'id'

  displayName: (->
    @get('name') || @get('slug')
  ).property 'name', 'slug'

klass.reopenClass
  fetch: ->
    hosts = Em.ArrayProxy.create()
    ajax(
      type: 'GET'
      url: '/api/v0/hosts'
    ).then (res) ->
      if Em.isArray(res.hosts)
        hosts.set 'content', res.hosts.map (h) ->
          App.Host.create
            id: h.id
            name: h.name
            slug: h.slug
            state: h.state
            hostname: h.hostname
            freighterdPort: h.freighterd_port
            proxyHostname: h.proxy_hostname
            ipAddress: h.ip_address
    , (jqxhr) ->
      json = jqxhr.responseJSON
      window.alert(json.error_description || json.error || "Failed to load hosts (#{jqxhr.statusText})")
    hosts
