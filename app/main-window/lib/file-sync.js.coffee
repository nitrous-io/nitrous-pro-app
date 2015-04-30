fs = require 'fs'
path = require 'path'
shell = require 'shell'
ipc = require 'ipc'
logger = require './lib/logger'

NITROUS_FOLDER_PATH = path.join(App.homePath, 'Nitrous')

App.FileSync = klass = Em.Object.extend
  container: null
  state: null
  watcher: null
  remoteWatcher: null
  started: false
  enabled: false
  unison: null
  syncIgnoreLastModified: null

  remoteWatcherIssues: false
  localWatcherIssues: false
  unisonIssues: false

  enableWhenReady: false

  init: ->
    @_super.apply this, arguments
    Em.run.next =>
      @controlWatcher()

  hostPath: (->
    if hostSlug = @get 'container.host.slug'
      path.join(NITROUS_FOLDER_PATH, hostSlug)
  ).property 'container.host.slug'

  syncPath: (->
    if (hostPath = @get 'hostPath') && (slug = @get 'container.slug')
      path.join(hostPath, slug)
  ).property 'hostPath', 'container.slug'

  enableWhenReadyWatcher: (->
    return unless @get('enableWhenReady')
    if App.get('online') && @get('hostPath') && @get('syncPath') && @get('container.sshUrl')
      @set 'enabled', true
      @set 'enableWhenReady', false
  ).observes 'App.online', 'hostPath', 'syncPath', 'container.sshUrl', 'enableWhenReady'

  controlWatcher: (->
    if @get('enabled') && @get('container.state') == 'running' && App.get('online') && @get('hostPath') && @get('syncPath') && @get('container.sshUrl')
      @startWatcher()
    else
      if @get("enabled") && !App.get("online")
        return # we do not want to shut down the sync utility during a network interruption
      @stopWatcher()
  ).observes 'enabled', 'container.state', 'App.online', 'hostPath', 'syncPath', 'container.sshUrl'

  syncIssues: (->
    @get('enabled') && (@get('remoteWatcherIssues') || @get('localWatcherIssues') || @get('unisonIssues'))
  ).property 'unisonIssues', 'remoteWatcherIssues', 'localWatcherIssues', 'enabled'

  enabledChanged: (->
    if @get 'enabled'
      App.track 'File Sync Enabled',
        container_id: @get('container').id
      if App.get('fileSyncTracker')
        App.get('fileSyncTracker').isEnabled @get('container').id
    else
      App.track 'File Sync Disabled',
        container_id: @get('container').id
      if App.get('fileSyncTracker')
        App.get('fileSyncTracker').isDisabled @get('container').id
  ).observes 'enabled'

  showSyncFolder: ->
    unless fs.existsSync @get('syncPath')
      return window.alert "Please enable File Sync for the first time to create your folder."

    if App.platform.isMac || App.platform.isWindows
      shell.openExternal "file://#{@get 'syncPath'}"
    else
      shell.openItem @get('syncPath')

  startWatcher: (cb) ->
    return if @get 'started'
    @set 'started', true

    syncPath = @get 'syncPath'
    hostPath = @get 'hostPath'

    # make nitrous folder
    fs.mkdir NITROUS_FOLDER_PATH, '0755', (err) =>
      return cb?(err) if err && err.code != 'EEXIST'
      fs.mkdir hostPath, '0755', (err) =>
        return cb?(err) if err && err.code != 'EEXIST'
        fs.mkdir syncPath, '0755', (err) =>
          return cb?(err) if err && err.code != 'EEXIST'
          @_initializeWatcher(cb)

  stopWatcher: ->
    if watcher = @get 'watcher'
      @_log 'stopping watcher...'
      watcher.stop()
      @set 'watcher', null
    if remoteWatcher = @get 'remoteWatcher'
      @_log 'stopping remote watcher...'
      remoteWatcher.stop()
      @set 'remoteWatcher', null
    if unison = @get 'unison'
      unison.abort()
      @set 'unison', null
    @set 'started', false
    @set 'enabled', false

  kickOffInitialSync: ->
    @set 'unison.syncOnly', 'Name .syncignore'
    @_log "Syncing across .syncignore"
    @performSync =>
      @loadSyncIgnore(true)
      @_log "Resuming regular sync"
      @set 'unison.syncOnly', null
      @performSync =>
        # initial sync succeeded, fire up watchers
        return unless @get 'started' # if sync is disabled before first sync is completed
        @_log 'starting watcher...'
        @get('watcher').start()
        @_log 'starting remote watcher...'
        @get('remoteWatcher').start()

  loadSyncIgnore: (force) ->
    unison = @get 'unison'
    return unless unison

    syncFile = path.join(@get('syncPath'), '.syncignore')
    if fs.existsSync syncFile
      fInfo = fs.statSync syncFile
      lastModified = fInfo.mtime.getTime()
      if lastModified != @get('syncIgnoreLastModified') || force
        @_log "Loading .syncignore"
        @set 'syncIgnoreLastModified', lastModified
        contents = fs.readFileSync(syncFile, 'utf8')
        unison.parseIgnoreContents contents
    else
      unison.parseIgnoreContents ""

  _initializeWatcher: (cb) ->
    syncPath = @get 'syncPath'
    container = @get 'container'
    slug = container.get 'slug'
    sshUrl = container.get 'sshUrl'

    @set 'unison', App.Unison.create(container: container, syncPath: syncPath, onRetry: =>
      @_unisonRestarting()
    , onRestored: =>
      @_unisonRestored()
    , onPatternError: (patt) =>
      @_unisonPatternError(patt)
    )
    @set 'watcher', watcher = new App.Watcher(syncPath)
    watcher.on 'change', (change) =>
      @_log "detected local fs change at #{change}"
      @loadSyncIgnore()
      @performSync()
    watcher.on 'watcherRestarting', (watcher) => @_watcherRestarting(watcher)
    watcher.on 'watcherRestored', (watcher) => @_watcherRestored(watcher)
    @set 'remoteWatcher', remoteWatcher = new App.Watcher(@container.get('syncPath'), ssh: sshUrl)
    remoteWatcher.on 'change', (change) =>
      @_log "detected remote fs change at #{change}"
      @performSync =>
        @loadSyncIgnore()
    remoteWatcher.on 'watcherRestarting', (watcher) => @_watcherRestarting(watcher)
    remoteWatcher.on 'watcherRestored', (watcher) => @_watcherRestored(watcher)
    # perform initial sync
    @kickOffInitialSync()
    cb?()

  _unisonRestarting: ->
    @set('unisonIssues', true)

  _unisonRestored: ->
    @set('unisonIssues', false)

  _watcherRestarting: (watcher) ->
    if watcher == @get('remoteWatcher')
      @set 'remoteWatcherIssues', true

    if watcher == @get('watcher')
      @set 'localWatcherIssues', true

  _watcherRestored: (watcher) ->
    if watcher == @get('remoteWatcher')
      @set 'remoteWatcherIssues', false

    if watcher == @get('watcher')
      @set 'localWatcherIssues', false

  _unisonPatternError: (patt) ->
    window.alert("Pattern: '#{patt}' is incorrect, please correct in .syncignore")
    @stopWatcher()

  _log: (firstMessage, others...) ->
    messages = ["[file-sync] #{@get('container.slug')}: #{firstMessage}"]
    messages.concat others
    logger.log messages

  performSync: (cb) ->
    return unless @get 'started'
    if unison = @get 'unison'
      unison.sync(cb)
    else
      cb?()
