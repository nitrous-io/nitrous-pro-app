Mixpanel = require './mixpanel'
config = require '../config'

module.exports = class MixpanelWrapper
  constructor: (token) ->
    @mixPanel = Mixpanel.init token

  track: (event_name, data) ->
    data = {} unless data
    data.appVersion = config.version
    data.platform = process.platform
    if @userEmail
      data.email = @userEmail
    if @userAdmin != null
      data.admin = @userAdmin
    @mixPanel.track event_name, data

  setUser: (user) ->
    @userEmail = user.email
    @userAdmin = user.admin
    @mixPanel.people.set user.username,
      $username: user.username
      $email: @userEmail
      admin: @userAdmin
      platform: process.platform
      appVersion: config.version