Mixpanel = require './mixpanel'
config = require '../config'

module.exports = class MixpanelWrapper
  constructor: (token) ->
    @mixPanel = Mixpanel.init token
    @distinctId = null

  track: (event_name, data) ->
    if config.env == "development"
       return console.log "[mix-panel] '#{event_name}' received in development"
    data = {} unless data
    data.appVersion = config.version
    data.platform = process.platform
    data.distinct_id = @distinctId
    if @userEmail
      data.email = @userEmail
    if @userAdmin != null
      data.admin = @userAdmin
    @mixPanel.track event_name, data

  setUser: (user) ->
    if config.env == "development"
       return console.log "[mix-panel] user '#{user.email}' in development"
    @userEmail = user.email
    @userAdmin = user.admin
    @distinctId = user.username
    @mixPanel.people.set user.username,
      $username: user.username
      $email: @userEmail
      admin: @userAdmin
      platform: process.platform
      appVersion: config.version