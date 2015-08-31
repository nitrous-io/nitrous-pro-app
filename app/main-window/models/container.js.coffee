ajax = require './lib/ajax'
path = require 'path'
fs = require 'fs'

App.Container = klass = Em.Object.extend
  id: null
  cid: null
  name: null
  user: null
  slug: null
  state: null
  image: null
  hostId: null
  previewHostname: null

  syncEnabled: false

  fileSync: null

  shared: false

  init: ->
    @_super.apply this, arguments
    @set 'fileSync', App.FileSync.create(container: this)

  restorePortForwarder: (->
    return unless @get('id') && @get('sshUrl')
    return if @get 'portForwarder'
    @set 'portForwarder', p = App.SSHPortForwarder.create(container: this)
    p.loadSettings()
  ).observes 'id', 'sshUrl'

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
    @refreshConfig()
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

  fileSyncSupported: (->
    @get('imageVersion') && @get('imageVersion') >= 1 && @get('sshAccessSupported') && @get('syncPath')
  ).property 'imageVersion', 'sshAccessSupported'

  sshAccessSupported: (->
    return unless @get 'envVarHash.NITROUS_SSH_ENABLED'
    @get('envVarHash.NITROUS_SSH_ENABLED') == "true" && @get('sshUrl')
  ).property 'envVarHash.NITROUS_SSH_ENABLED', 'sshUrl'

  parsedPorts: (->
    ports = {}
    if portBindings = @get 'config.port'
      for portBinding in portBindings
        if portMatch = portBinding.match(/^(public|private):(\d+):(\d+)(\/tcp)?$/)
          ports["#{portMatch[1]}:#{portMatch[3]}"] = portMatch[2]
    ports
  ).property 'config.port.@each'

  sshPort: (->
    @get('parsedPorts')?["public:22"]
  ).property 'parsedPorts'

  sshUrl: (->
    sshUsername = @get 'sshUsername'
    hostAddress = @get 'host.ipAddress'
    sshPort = @get 'sshPort'
    return unless sshUsername && hostAddress && sshPort
    "ssh://#{sshUsername}@#{hostAddress}:#{sshPort}"
  ).property 'sshUsername', 'host.ipAddress', 'sshPort'

  previewPort: (->
    return null unless port = @get 'envVarHash.NITROUS_PREVIEW_PORT'
    port = window.parseInt port
    return null if isNaN(port)
    port
  ).property 'envVarHash.NITROUS_PREVIEW_PORT'

  previewUrl: (->
    hostname = @get 'previewHostname'
    port = @getWithDefault 'previewPort', 3000
    return unless @get('parsedPorts')?["public:#{port}"]
    return unless hostname && port
    "http://#{hostname}:#{port}"
  ).property 'host.hostname', 'previewPort'

  loginUsername: (->
    u = @get('envVarHash')?["NITROUS_USERNAME"] || @get('user')
    if u == ""
      return "root"
    u
  ).property 'envVarHash'

  syncPath: (->
    if (r = @get('envVarHash.NITROUS_ROOT_SYNC'))
      r
    else if @get('loginUsername') != "root" && (p = @get('envVarHash.NITROUS_IMAGE_VERSION'))
      "/home/#{@get 'loginUsername'}/code"
    else
      null
  ).property 'envVarHash', 'loginUsername'

  applyFromJsonObject: (c)->
    @setProperties
      id: c.id
      cid: c.cid
      name: c.name
      slug: c.slug
      state: c.state
      image: c.image
      hostId: c.host_id
      previewHostname: c.preview_hostname
      user: c.user

  refreshConfig: ->
    ajax(
      type: 'GET'
      url: "/api/v0/containers/#{@get 'id'}/config"
    ).then (res) =>
      @set 'config.content', res.config

klass.reopenClass
  fetchEachRaw: (eachFunc, cb) ->
    containers = Em.ArrayProxy.create()
    ajax(
      type: 'GET'
      url: '/api/v0/containers'
    ).then (res) ->
      if Em.isArray(res.containers)
        containers.set 'content', res.containers.map (c) ->
          eachFunc(c)
      cb?(containers)
    , (jqxhr) ->
      json = jqxhr.responseJSON
      window.alert(json?.error_description || json?.error || "Failed to load containers (#{jqxhr.statusText})")
    containers

  fetch: (cb) ->
    @fetchEachRaw (c) ->
      container = App.Container.create()
      container.applyFromJsonObject c
      container.get 'config'
      container
    , (containers) ->
      cb?(containers)
