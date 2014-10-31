fs = require 'fs'
ajax = require './lib/ajax'
path = require 'path'

NITROUS_FOLDER_PATH = path.join(App.homePath, 'Nitrous')

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

  sshUsername: (->
    username = null
    if envVars = @get 'config.env'
      for envVar in envVars
        break if username = envVar.match(/^NITROUS_USERNAME=(.+)$/)?[1]
    username
  ).property 'config.env.@each'

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
