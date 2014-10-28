#= require init-jquery
#= require init-ember
#= require_self

ipc = require 'ipc'

ipc.on 'load-js', (js) ->
  $('head').append($('<script>').attr('src', js + '.js'))
