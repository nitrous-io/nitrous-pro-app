config       = require './config'
path         = require 'path'
fs           = require 'fs'
https        = require 'https'
url          = require 'url'
childProcess = require 'child_process'

UPDATE_CHECK_INTERVAL = 6 * 60 * 60 * 1000  # 6 hours
CHECK_RETRY_LIMIT = 5
CHECK_RETRY_WAIT = 5000

UPDATE_SCRIPT_PATH = path.join(App.binPath,
  "nitrous-update.#{if App.platform.isWindows then 'cmd' else 'sh'}")

App.Updater = Em.Object.extend

  checking: false
  updating: false
  downloading: false
  installing: false

  checkFailed: false
  updateFailed: false

  downloadedBytes: 0

  newUrl: null
  newFileSize: null
  newVersion: null

  checkRetries: 0

  updateInfo: (->
    @get('checking') || @get('updating') || @get('downloading') || @get('installing')
  ).property 'checking', 'updating', 'downloading', 'installing'

  progress: (->
    bytes = @get 'downloadedBytes'
    fSize = @get 'newFileSize'
    return null unless bytes && fSize
    (Math.round((bytes / fSize * 100.0) * 10) / 10).toFixed(1)
  ).property 'downloadedBytes', 'newFileSize'

  startSchedule: ->
    @_log "Started. Current version: " + config.version
    @checkForUpdates()
    @schedule = window.setInterval(=>
      @checkForUpdates()
    , UPDATE_CHECK_INTERVAL)

  stopSchedule: ->
    if @schedule
      window.clearInterval @schedule
    @schedule = null

  checkForUpdates: ->
    return if @get 'checking'

    @set 'checking', true
    @set 'checkFailed', false
    @set 'updateFailed', false

    platformDir = if App.platform.isWindows
      "windows"
    else if App.platform.isMac
      "mac"
    else if App.platform.isLinux
      "linux"
    else
      null

    unless platformDir && config.updateLocation && config.version
      @set 'checking', false
      return

    updateCheckUrl = "#{config.updateLocation}/#{platformDir}/app.json"
    window.$.ajax(
      type: 'GET'
      cache: false
      url: updateCheckUrl
      dataType: 'json'
    ).done((json) =>
      @processUpdate json
    ).fail((jqxhr) =>
      @set 'checkFailed', true

      @set('checkRetries', @get('checkRetries') + 1)

      if @get('checkRetries') > CHECK_RETRY_LIMIT
        @set 'checkRetries', 0
        return

      window.setTimeout =>
        @checkForUpdates()
      , CHECK_RETRY_WAIT
    ).always =>
      @set 'checking', false

  processUpdate: (json) ->
    if @compareVersion(json.version, config.version)
      if json.url && json.fileSize
        @set('newUrl', json.url)
        @set('newFileSize', json.fileSize)
        @set('newVersion', json.version)
        @promptUser()
      else
        @set 'updateFailed', true
    else
      @_log "Server version: #{json.version}"

  promptUser: ->
    message = "A new version (#{@get('newVersion')}) is available, would you like to update?"
    willUpdate = window.confirm message
    if willUpdate
      @downloadUpdate()

  fail: ->
    @set 'updating', false
    @set 'downloading', false
    @set 'updateFailed', true

  downloadUpdate: ->
    return if @get 'updating'
    @set 'updating', true

    @set 'downloading', true
    @set 'downloadedBytes', 0

    newUrl = @get 'newUrl'

    updatesPath = path.join App.dataPath, "Updates"
    fs.mkdir updatesPath, =>
      fileName = path.basename newUrl
      @downloadPath = path.join updatesPath, fileName
      tempDownloadPath = @downloadPath + ".downloading"

      writeStream = fs.createWriteStream tempDownloadPath, encoding: 'binary'

      parsed = url.parse newUrl
      options =
        method: 'GET'
        hostname: parsed.hostname
        port: parsed.port ? 443
        path: parsed.path
        headers:
          'user-agent': window.navigator.userAgent
          accept: '*/*'

      request = https.request options, (res) =>
        contentLength = window.parseInt res.headers['content-length'], 10
        @_log "#{res.statusCode}, Length: #{contentLength} bytes"
        if res.statusCode != 200 || contentLength != @get('newFileSize')
          @_log 'Failed!'
          request.abort()
          writeStream.end()
          @fail()
          return false

        res.setEncoding 'binary'
        res.on 'data', (chunk) =>
          @set 'downloading', true
          writeStream.write chunk, 'binary'
          @set 'downloadedBytes', @get('downloadedBytes') + chunk.length

        res.on 'end', =>
          writeStream.end()
          fs.rename tempDownloadPath, @downloadPath, =>
            @_log 'Download Finished'
            @set 'downloading', false
            @installUpdate()

      request.on 'error', (err) =>
        request.abort()

        @_log "Update failed! #{err.message}"
        writeStream.end()
        @fail()

      request.end()

  installUpdate: ->
    if config.env == 'development'
      @_log 'In development mode, update will not install'
      @set 'updating', false
      @set 'updateFailed', true
      return

    appPath = App.appPath
    installPath = path.join appPath, '..'

    writeTestFilePath = path.join installPath, '.nitrous-desktop-install'
    fs.writeFile writeTestFilePath, '', (err) =>
      if App.platform.isMac && err
        @_log 'Unable to write to install directory. Aborting.'
        @set 'updateFailed', true
        @set 'updating', false
        return

      fs.unlink(writeTestFilePath)

      args = [
        process.pid
        appPath
        @downloadPath
      ]

      options =
        cwd: installPath
        detached: true

      if App.platform.isWindows
        update_script_in_temp_path = path.join process.env.TEMP, 'nitrous-update.cmd'
        fs.writeFileSync(update_script_in_temp_path, fs.readFileSync(UPDATE_SCRIPT_PATH))
        args.unshift '/c', 'start', 'Updating Nitrous Desktop...', '/min', update_script_in_temp_path
        childProcess.spawn 'cmd.exe', args, options
      else
        args.unshift UPDATE_SCRIPT_PATH
        childProcess.spawn '/bin/bash', args, options

      Em.run.next ->
        App.quit()

  compareVersion: (a, b) ->
    [aMajor, aMinor, aPatch] = a.split '.'
    [bMajor, bMinor, bPatch] = b.split '.'
    aMajor.localeCompare(bMajor) ||
      aMinor.localeCompare(bMinor) ||
      aPatch.localeCompare(bPatch)

  _log: (firstMessage, others...) ->
    return unless config.debug
    messages = ["[updater] #{firstMessage}"]
    messages.concat others
    console.log.apply console, messages