config = require '../config'

module.exports = (options={}) ->
  if token = window.localStorage.getItem 'access-token'
    options.headers ||= {}
    options.headers['Authorization'] = "Bearer #{token}"
  if config.host
    options.url = config.host + options.url
  window.$.ajax(options)
