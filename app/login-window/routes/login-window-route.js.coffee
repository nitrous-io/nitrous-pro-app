ipc = require 'ipc'
ajax = require './lib/ajax'

App.LoginWindowRoute = Em.Route.extend
  setupController: (controller) ->
    @_super.apply this, arguments
    return unless token = window.localStorage.getItem 'access-token'
    controller.set 'loggingIn', true
    ajax(
      type: 'GET'
      url: '/api/v0/user'
    ).then (res) ->
      ipc.send 'logged-in', token
    , (jqxhr) ->
      if jqxhr.status == 401
        window.localStorage.removeItem 'access-token'
      else
        json = jqxhr.responseJSON
        window.alert(json.error_description || json.error || jqxhr.statusText)
      controller.set 'loggingIn', false
