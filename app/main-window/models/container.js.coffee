ajax = require './lib/ajax'
path = require 'path'
fs = require 'fs'

App.Container = klass = Em.Object.extend
  id: null
  cid: null
  name: null
  slug: null
  state: null
  image: null
  hostId: null

  syncEnabled: false

  fileSync: null

  init: ->
    @_super.apply this, arguments
    @set 'fileSync', App.FileSync.create(container: this)

  displayName: (->
    @get('name') || @get('slug')
  ).property 'name', 'slug'

  selected: (->
    App.get('selectedContainer') == this
  ).property 'App.selectedContainer'

  host: (->
    App.get('hosts').findBy('id', @get('hostId'))
  ).property 'hostId', 'App.hosts.@each'

  config: (->
    config = Em.ObjectProxy.create()
    ajax(
      type: 'GET'
      url: "/api/v0/containers/#{@get 'id'}/config"
    ).then (res) =>
      config.set 'content', res.config
    config
  ).property 'id'

  configLoaded: Em.computed.notEmpty 'config.content'

  envVarHash: (->
    hash = {}
    return hash unless envVars = @get 'config.env'
    for v in envVars
      m = v.match /^([^=]+)=(.*)$/
      key = m[1]
      val = m[2]
      hash[key] = val
    hash
  ).property 'config.env.@each'

  sshUsername: Em.computed.alias 'envVarHash.NITROUS_USERNAME'

  imageVersion: (->
    version = window.parseInt(@get('envVarHash.NITROUS_IMAGE_VERSION'), 10)
    return null if isNaN(version)
    version
  ).property 'envVarHash.NITROUS_IMAGE_VERSION'

  fileSyncSupported: Em.computed.gte 'imageVersion', 1

  sshPort: (->
    port = null
    if portBindings = @get 'config.port'
      for portBinding in portBindings
        break if port = portBinding.match(/^public:(.+):22(\/tcp)?$/)?[1]
    port
  ).property 'config.port.@each'

  sshUrl: (->
    sshUsername = @get 'sshUsername'
    hostname = @get 'host.hostname'
    sshPort = @get 'sshPort'
    return unless sshUsername && hostname && sshPort
    "ssh://#{sshUsername}@#{hostname}:#{sshPort}"
  ).property 'sshUsername', 'host.hostname', 'sshPort'

klass.reopenClass
  fetch: ->
    containers = Em.ArrayProxy.create()
    ajax(
      type: 'GET'
      url: '/api/v0/containers'
    ).then (res) ->
      if Em.isArray(res.containers)
        containers.set 'content', res.containers.map (c) ->
          container = App.Container.create
            id: c.id
            cid: c.cid
            name: c.name
            slug: c.slug
            state: c.state
            image: c.image
            hostId: c.host_id
          container.get 'config'
          container
    , (jqxhr) ->
      json = jqxhr.responseJSON
      window.alert(json?.error_description || json?.error || "Failed to load containers (#{jqxhr.statusText})")
    containers
