return unless App.platform.isWindows

childProcess = require 'child_process'
fs = require 'fs'
path = require 'path'

TRUE_HOME_PATH = process.env.HOME || process.env.USERPROFILE

SSH_BIN_PATH = path.join(App.binPath, 'nitrous-ssh.exe')
MINTTY_BIN_PATH = path.join(App.binPath, 'mintty.exe')

SSH_ICON_PATH = path.join(App.binPath, 'ssh-icon.ico')

App.mintty =
  ssh: (user, host, port, title, sshKeyFile) ->
    args = [
      '--option', 'Locale=en_US'
      '--option', 'Charset=UTF-8'
      '--option', 'Term=xterm-256color'
      '--icon', SSH_ICON_PATH
      '--exec', SSH_BIN_PATH
      '-o', 'UserKnownHostsFile=NUL'
      '-o', 'StrictHostKeyChecking=no'
      '-o', 'PreferredAuthentications=publickey'
      '-o', 'LogLevel=FATAL'
      '-c', 'blowfish-cbc'
      '-i', sshKeyFile
      '-p', port
      "#{user}@#{host}"
    ]

    if title
      args.unshift '--title', title

    env = {}
    window.$.extend(true, env, process.env)
    env.HOME = App.homePath

    options =
      cwd: App.homePath
      env: env

    childProcess.execFile MINTTY_BIN_PATH, args, options