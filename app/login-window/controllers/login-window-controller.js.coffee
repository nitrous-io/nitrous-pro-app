ipc = require 'ipc'
config = require './config'
ajax = require './lib/ajax'
shell = require 'shell'

App.LoginWindowController = Em.Controller.extend
  loggingIn: false
  username: null
  password: null
  invalidCredentials: false

  fail: (jqxhr) ->
    Em.run.scheduleOnce 'afterRender', ->
      json = jqxhr.responseJSON
      window.alert((json?.error_description || json?.error || jqxhr.statusText).toString().capitalize())
    @set 'loggingIn', false

  fetchUser: ->
    ajax(
      type: 'GET'
      url: '/api/v0/user'
    ).then (res) ->
      username = res.user.username
      ipc.send 'logged-in', username
    , (jqxhr) =>
      if jqxhr.status == 401
        window.localStorage.removeItem 'access-token'
      @fail(jqxhr)

  actions:
    login: ->
      @setProperties
        loggingIn: true
        invalidCredentials: false

      ajax(
        type: 'POST'
        url: '/api/v0/oauth/token'
        data:
          grant_type: 'password'
          username: @get 'username'
          password: @get 'password'
      ).then (res) =>
        token = res.access_token
        window.localStorage.setItem 'access-token', token
        @fetchUser()
      , (jqxhr) =>
        if jqxhr.status == 400 && jqxhr.responseJSON?.error == 'invalid_grant'
          @setProperties
            invalidCredentials: true
            loggingIn: false
        else
          @fail(jqxhr)

    signUp: ->
      shell.openExternal(config.signUpUrl)
