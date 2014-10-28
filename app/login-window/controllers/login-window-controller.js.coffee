ipc = require 'ipc'
config = require './config'

App.LoginWindowController = Em.Controller.extend
  loggingIn: false
  username: null
  password: null

  actions:
    login: ->
      @set 'loggingIn', true
      $.ajax(
        type: 'POST'
        url: "#{config.host}/api/v0/oauth/token"
        data:
          grant_type: 'password'
          username: @get 'username'
          password: @get 'password'
      ).then (res) ->
        ipc.send 'access-token', res.access_token
      , (jqxhr) =>
        json = jqxhr.responseJSON
        window.alert(json.error_description || json.error)
        @set 'loggingIn', false
