#= require init-jquery
#= require init-ember
#= require_self

# prevent user from dragging and dropping random shit onto app window

document.body.addEventListener('dragover', (e) ->
  e.preventDefault()
  e.stopPropagation()
, false)

document.body.addEventListener('drop', (e) ->
  e.preventDefault()
  e.stopPropagation()
, false)

ipc = require 'ipc'

ipc.on 'load-js', (js) ->
  $('head').append($('<script>').attr('src', js + '.js'))
