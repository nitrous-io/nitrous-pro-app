path = require 'path'
childProcess = require 'child_process'

LAUNCH_BIN_PATH = if App.platform.isLinux
  path.join(App.binPath, "xdg-terminal")
else
  path.join(App.binPath, "nitrous-ssh-launcher")
SSH_BIN_PATH = if App.platform.isWindows
  path.join(App.binPath, 'nitrous-ssh.exe')
else
  path.join(App.binPath, 'nitrous-ssh')

App.SSHShell = Em.Object.extend
  sshUser: null
  hostname: null
  port: null
  privateKeyPath: null
  container: null

  attemptedUpload: false

  startShell: (container) ->
    @set('container', container)
    @set('sshUser', container.get('sshUsername'))
    @set('hostAddress', container.get('host.ipAddress'))
    @set('port', container.get('sshPort'))
    @set('privateKeyPath', App.get 'sshKey.privateKeyPath')

    @_testAndLaunch()

  _testAndLaunch: ->
    # test SSH is okay incase we need to upload keys
    baseSshArgs = [
      '-o', 'UserKnownHostsFile=/dev/null'       # ignore known hosts
      '-o', 'StrictHostKeyChecking=no'           # no host key checking
      '-o', 'PreferredAuthentications=publickey' # pub key authentication only
      '-o', 'LogLevel=FATAL'
      '-p', @get('port')
      '-i', @get('privateKeyPath')
      "#{@get('sshUser')}@#{@get('hostAddress')}"
    ]

    testSSHArgs = baseSshArgs.concat ["echo nitrous-success"]

    @proc = childProcess.spawn SSH_BIN_PATH, testSSHArgs, detached: false
    @waitTimeout = window.setTimeout(=>
      @_testTimedOut()
    , 60000)
    if false && @proc.exitCode == 255
      @_cancelTimeout()
      console.log "Unable to launch shell, server not available."

    @proc.stdout.on 'data', (data) => @_handleTestShell(baseSshArgs, data)
    @proc.stderr.on 'data', (data) => @_handleTestShell(baseSshArgs, data)

  _handleTestShell: (sshArgs, data) ->
    decoded = data.toString('utf8')
    console.log decoded

    if decoded.indexOf("nitrous-success") != -1
      @_cancelTimeout()

      # invoke SSH interactively
      if App.platform.isWindows
        console.log "Starting mintty for Windows"
        App.mintty.ssh(@get('sshUser'), @get('hostAddress'), @get('port'), @get('container.displayName'), @get('privateKeyPath'))
      else
        sshArgs.unshift SSH_BIN_PATH
        identityLoc = sshArgs.indexOf('-i') + 1

        if App.platform.isLinux
          sshArgs[identityLoc] = sshArgs[identityLoc].replace " ", "\\ "
        else
          sshArgs[identityLoc] = "\"#{sshArgs[identityLoc]}\""

        if App.platform.isLinux
          sshArgs = [sshArgs.join(" ")]

        console.log LAUNCH_BIN_PATH + " " + sshArgs.join " "
        childProcess.spawn LAUNCH_BIN_PATH, sshArgs, detached: false
    else if decoded.indexOf("Permission denied") != -1
      @_cancelTimeout()

      if @get('attemptedUpload')
        window.alert("Unable to launch shell, service rejected uploaded key")
        return @set('attemptedUpload', false)

      App.get('sshKey').upload @get('container'), (err) =>
        @set('attemptedUpload', true)
        if err
          window.alert("Unable to launch shell, key upload failed")
        else
          @_testAndLaunch()
    else if decoded.indexOf("Operation timed out") != -1
      @_cancelTimeout()

      window.alert("Unable to launch shell, server failed to respond")
    else if decoded.indexOf("Could not resolve") != -1
      @_cancelTimeout()

      window.alert("Unable to launch shell, server address not found")

  _cancelTimeout: ->
    if @waitTimeout
      window.clearTimeout @waitTimeout

  _testTimedOut: ->
    if @proc
      @proc.kill('SIGKILL')
    window.alert "Unable to launch shell, timed out. Server may not be responding"
