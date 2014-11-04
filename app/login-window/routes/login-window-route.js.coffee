ipc = require 'ipc'
ajax = require './lib/ajax'

App.LoginWindowRoute = Em.Route.extend
  setupController: (controller) ->
    @_super.apply this, arguments
    return unless token = window.localStorage.getItem 'access-token'
    controller.set 'loggingIn', true
    controller.fetchUser()
