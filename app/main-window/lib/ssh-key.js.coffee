path = require 'path'
childProcess = require 'child_process'
os = require 'os'
fs = require 'fs'
ajax = require './lib/ajax'

KEYGEN_BIN_PATH = if App.platform.isWindows
  path.join(App.binPath, 'nitrous-ssh-keygen.exe')
else
  path.join(App.binPath, 'nitrous-ssh-keygen')

App.SSHKey = klass = Em.Object.extend
  publicKey: null

  privateKeyPath: (->
    path.join App.get('userDataPath'), 'id_rsa'
  ).property 'App.userDataPath'

  publicKeyPath: (->
    path.join App.get('userDataPath'), 'id_rsa.pub'
  ).property 'App.userDataPath'

  upload: (container, cb) ->
    upload = =>
      ajax(
        type: 'POST'
        url: "/api/v0/containers/#{container.get 'id'}/keys"
        data:
          key: @get 'publicKey'
      ).then (res) ->
        cb?()
      , (jqxhr) ->
        json = jqxhr.responseJSON
        cb?(new Error(json?.error_description || json?.error || "Failed to upload SSH key"))

    if @get("publicKey") == null
      @load (err) =>
        return cb?(err) if err
        upload()
    else
      upload()

  # load ssh key, generate if not exists
  load: (cb) ->
    privateKeyPath = @get 'privateKeyPath'
    publicKeyPath = @get 'publicKeyPath'

    load = =>
      fs.readFile publicKeyPath, encoding: 'utf8', (err, data) =>
        return cb?(err) if err
        @set 'publicKey', data
        cb?()

    fs.exists privateKeyPath, (privateKeyExists) ->
      fs.exists publicKeyPath, (publicKeyExists) ->
        return load() if privateKeyExists && publicKeyExists

        passphrase = if App.platform.isWindows then "''" else '' # empty passphrase
        args = [
          '-b', '2048' # bits
          '-t', 'rsa'  # type
          '-N', passphrase
          '-C', "nitrous-desktop-app@#{os.hostname().replace /\.local$/, ''}"  # name/comment
          '-f', privateKeyPath
        ]
        childProcess.execFile KEYGEN_BIN_PATH, args, {}, (err, stdout, stderr) ->
          return cb?(err) if err
          load()

  deleteKeys: ->
    @set 'publicKey', null
    try for keyPath in [@get('privateKeyPath'), @get('publicKeyPath')]
      fs.unlinkSync(keyPath) if keyPath
