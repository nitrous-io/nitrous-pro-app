fs = require 'fs'
path = require 'path'
shell = require 'shell'
ipc = require 'ipc'

NITROUS_FOLDER_PATH = path.join(App.homePath, 'Nitrous')

App.FileSync = klass = Em.Object.extend
  container: null
  state: null
  watcher: null
  remoteWatcher: null
  started: false
  enabled: false
  unison: null

  remoteWatcherIssues: false
  localWatcherIssues: false
  unisonIssues: false

  init: ->
    @_super.apply this, arguments
    Em.run.next =>
      @controlWatcher()

  syncPath: (->
    if slug = @get 'container.slug'
      path.join(NITROUS_FOLDER_PATH, slug)
  ).property 'container.slug'

  controlWatcher: (->
    if @get('enabled') && @get('container.state') == 'running' && App.get('online') && @get('syncPath') && @get('container.sshUrl')
      @startWatcher()
    else
      @stopWatcher()
  ).observes 'enabled', 'container.state', 'App.online', 'syncPath', 'container.sshUrl'

  syncIssues: (->
    @get('enabled') && (@get('remoteWatcherIssues') || @get('localWatcherIssues') || @get('unisonIssues'))
  ).property 'unisonIssues', 'remoteWatcherIssues', 'localWatcherIssues', 'enabled'

  enabledChanged: (->
    if @get 'enabled'
      App.track 'File Sync Enabled',
        container_id: @get('container').id
    else
      App.track 'File Sync Disabled',
        container_id: @get('container').id
  ).observes 'enabled'

  showSyncFolder: ->
    if App.platform.isMac || App.platform.isWindows
      shell.openExternal "file://#{@get 'syncPath'}"
    else
      shell.openItem @get('syncPath')

  startWatcher: (cb) ->
    return if @get 'started'
    @set 'started', true

    syncPath = @get 'syncPath'
    container = @get 'container'
    slug = container.get 'slug'
    sshUrl = container.get 'sshUrl'

    # make nitrous folder
    fs.mkdir NITROUS_FOLDER_PATH, '0755', (err) =>
      return cb?(err) if err && err.code != 'EEXIST'
      fs.mkdir syncPath, '0755', (err) =>
        return cb?(err) if err && err.code != 'EEXIST'
        # initialize watcher
        @set 'unison', App.Unison.create(container: container, syncPath: syncPath, onRetry: =>
          @_unisonRestarting()
        , onRestored: =>
          @_unisonRestored()
        )
        @set 'watcher', watcher = new App.Watcher(syncPath)
        watcher.on 'change', (change) =>
          @_log "detected local fs change at #{change}"
          @performSync()
        watcher.on 'watcherRestarting', (watcher) => @_watcherRestarting(watcher)
        watcher.on 'watcherRestored', (watcher) => @_watcherRestored(watcher)
        @set 'remoteWatcher', remoteWatcher = new App.Watcher('~/workspace', ssh: sshUrl)
        remoteWatcher.on 'change', (change) =>
          @_log "detected remote fs change at #{change}"
          @performSync()
        remoteWatcher.on 'watcherRestarting', (watcher) => @_watcherRestarting(watcher)
        remoteWatcher.on 'watcherRestored', (watcher) => @_watcherRestored(watcher)
        # perform initial sync
        @kickOffInitialSync()
        cb?()

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
    @performSync =>
      # initial sync succeeded, fire up watchers
      return unless @get 'started' # if sync is disabled before first sync is completed
      @_log 'starting watcher...'
      @get('watcher').start()
      @_log 'starting remote watcher...'
      @get('remoteWatcher').start()

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

  _log: (firstMessage, others...) ->
    messages = ["[file-sync] #{@get('container.slug')}: #{firstMessage}"]
    messages.concat others
    console.log.apply console, messages

  performSync: (cb) ->
    return unless @get 'started'
    if unison = @get 'unison'
      unison.sync(cb)
    else
      cb?()
