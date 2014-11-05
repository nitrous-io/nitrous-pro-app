fs = require 'fs'
path = require 'path'

NITROUS_FOLDER_PATH = path.join(App.homePath, 'Nitrous')

App.FileSync = klass = Em.Object.extend
  container: null
  state: null
  watcher: null
  remoteWatcher: null
  started: false
  enabled: false
  unison: null

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
        @set 'unison', App.Unison.create(container: container, syncPath: syncPath)
        @set 'watcher', watcher = new App.Watcher(syncPath)
        watcher.on 'change', (change) =>
          console.log "#{slug}: detected local fs change at #{change}"
          @performSync()
        @set 'remoteWatcher', remoteWatcher = new App.Watcher('~/workspace', ssh: sshUrl)
        remoteWatcher.on 'change', (change) =>
          console.log "#{slug}: detected remote fs change at #{change}"
          @performSync()
        # perform initial sync
        @kickOffInitialSync()
        cb?()

  stopWatcher: ->
    if watcher = @get 'watcher'
      console.log "#{@get 'container.slug'}: stopping watcher..."
      watcher.stop()
      @set 'watcher', null
    if remoteWatcher = @get 'remoteWatcher'
      console.log "#{@get 'container.slug'}: stopping remote watcher..."
      remoteWatcher.stop()
      @set 'remoteWatcher', null
    if unison = @get 'unison'
      unison.abort()
      @set 'unison', null
    @set 'started', false

  kickOffInitialSync: ->
    @performSync =>
      # initial sync succeeded, fire up watchers
      return unless @get 'started' # if sync is disabled before first sync is completed
      slug = @get('slug')
      console.log "#{slug}: starting watcher..."
      @get('watcher').start()
      console.log "#{slug}: starting remote watcher..."
      @get('remoteWatcher').start()

  performSync: (cb) ->
    return unless @get 'started'
    if unison = @get 'unison'
      unison.sync(cb)
    else
      cb?()
