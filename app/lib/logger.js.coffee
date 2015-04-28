childProcess = require 'child_process'
fs           = require 'fs'
path         = require 'path'

module.exports =
  setLogPath: (loc) ->
    if @logFile
      @logFile.end()
    date = new Date()
    dateStr = date.toDateString().replace(/\s+/g, "_")
    @logFile = fs.createWriteStream path.join(loc, "#{dateStr}.log"), flags: 'a+'

  log: (messages) ->
    console.log.apply console, messages

    processOutput = (data) ->
      data = data.toString('utf8')
      console.log data

    if @logFile
      @logFile.write messages.join(" ")

    if App.platform.isMac
      message = messages.join(" ").replace(/"/gi, "\\\"")
      args = [
        "-c"
        "logger -t nitrous-desktop \"#{message}\""
      ]

      options =
        cwd: "/tmp"
        detached: true
      proc = childProcess.spawn '/bin/bash', args, options
      proc.stdout.on 'data', (data) => processOutput(data)
      proc.stderr.on 'data', (data) => processOutput(data)