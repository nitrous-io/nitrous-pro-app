ipc = require 'ipc'
config = require './config'

App.LoginWindowRoute = Em.Route.extend
  activate: ->
    @_super.apply this, arguments
    return unless token = window.localStorage.getItem 'access-token'
    $.ajax(
      type: 'GET'
      url: "#{config.host}/api/v0/user"
      headers:
        Authorization: "Bearer #{token}"
    ).then (res) ->
      ipc.send 'logged-in', token
    , (jqxhr) ->
      if jqxhr.status == 401
        window.localStorage.removeItem 'access-token'
      else
        json = jqxhr.responseJSON
        window.alert(json.error_description || json.error || jqxhr.statusText)
