#= require ./socket/socket

config = require './config'
logger = require './lib/logger'

App.EventsSocket = App.Socket.extend
  init: ->
    @_super.apply this, arguments
    @_addEventHandlers()

  connect: ->
    origin = config.host.replace('http', 'ws')
    token = encodeURIComponent(window.localStorage.getItem 'access-token')
    @set 'url', "#{origin}/api/v0/events?token=#{token}"
    @_super.apply this, arguments

  didOpen: (ev) ->
    @_super.apply this, arguments

  didReceiveMessage: (ev) ->
    msg = JSON.parse(ev.data)
    @trigger msg.name, msg.data
    @_super.apply this, arguments

  _addEventHandlers: ->
    ['container.created', 'container.destroyed'].forEach (evt) =>
      @on evt, (data) =>
        containerData = data.container
        @refreshContainers(containerData)

    ['container.started', 'container.stopped', 'container.restarted', 'container.updated', 'container.reconfigured', 'container.reconfigure_failed'].forEach (evt) =>
      @on evt, (data) ->
        @refreshContainers()

    ['host.created', 'host.create_failed', 'host.destroyed'].forEach (evt) =>
      @on evt, (data) ->
        @refreshHosts()

    ['host.started', 'host.stopped', 'host.restarted', 'host.updated',
      'host.starting', 'host.stopping', 'host.restarting'].forEach (evt) =>
      @on evt, (data) ->
        @refreshHosts()

  refreshHosts: ->
    App.Host.fetch (hosts) =>
      App.set 'hosts', hosts
      @refreshContainers()

  refreshContainers: (container) ->
    cb = () =>
      App.fetchContainers()

    if container
      hostId = container.host_id
      matchingHost = App.get('hosts').findBy 'id', hostId
      if matchingHost
        cb()
      else
        @_log "New host as part of new container, will refresh hosts + containers"
        @refreshHosts()
    else
      cb()

  _log: (firstMessage, others...) ->
    messages = ["[events] #{firstMessage}"]
    messages.concat others
    logger.log messages