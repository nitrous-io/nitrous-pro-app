shell = require 'shell'

App.Preview =
  previewContainer: (container) ->
    return unless url = container.get 'previewUrl'
    shell.openExternal url