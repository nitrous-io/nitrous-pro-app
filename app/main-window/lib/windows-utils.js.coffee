childProcess = require 'child_process'
logger = require './lib/logger'
path = require 'path'

SHORTNAME_BIN_PATH = path.join(App.binPath, 'ShortNameHelper.exe')

App.windowsUtils =
  getWindowsShortName: (path)->
    args = ["/c", SHORTNAME_BIN_PATH]
    split = path.split(" ")
    args = args.concat split
    res = childProcess.spawnSync("cmd", args)
    unless res && res.stdout && (out = res.stdout.toString())
      window.alert("Unable to resolve Windows path. Please contact support. Path tried: #{path} Args used: #{args}")
      if res.stderr && (es = res.stderr.toString()) && es.length > 0
        @_log es
      return null
    out.trim()

  _log: (firstMessage, others...) ->
    messages = ["[windows] #{firstMessage}"]
    messages = messages.concat others
    logger.log messages