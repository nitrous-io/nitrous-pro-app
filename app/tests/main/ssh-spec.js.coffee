childProcess = require 'child_process'

withWindow "main", ->
  setupForContainer = ()->
    fakeContainer = {}
    fakeContainer.get = (nm)->
      return "ssh://user@bla:2203"

    sshKey = {}
    App.set('sshKey', sshKey)
    sshKey.upload = (con, cb)->
      sshKey.uploadContainer = con
      sshKey.uploadCallback?(cb)

    {fakeContainer: fakeContainer, sshKey: sshKey}

  spinUpTestServer = ()->
    childProcess.spawn("#{__dirname}/mock-ssh/mock-ssh", ["#{__dirname}/mock-ssh/id_rsa"], detached: false)

  asyncTest 'App.SSH should feedback results from the client to a callback', (assert) =>
    gotData = false
    verify = ()=>
      assert.equal(gotData, true, "Expected data to be returned")
      QUnit.start()

    tm = null
    set = setupForContainer()
    dataReceived = (data)=>
      if data.indexOf("Could not resolve hostname bla") != -1
        clearTimeout(tm)
        gotData = true
        verify()

    ssh = new App.SSH(set.fakeContainer, {onData: dataReceived, restartOnExit: false})
    ssh.start()

    tm = setTimeout(=>
      ssh.stop()
      verify()
    , 500)

  asyncTest 'App.SSH should upload public key on error', (assert) =>
    set = setupForContainer()
    verify = ()=>
      assert.equal(set.sshKey.uploadContainer, set.fakeContainer, "Expected upload to be triggered")
      QUnit.start()

    tm = null
    set.sshKey.uploadCallback = (cb)=>
      clearTimeout(tm)
      verify()

    ssh = new App.SSH(set.fakeContainer, {restartOnExit: false})
    ssh.start()

    tm = setTimeout(=>
      ssh.stop()
      verify()
    , 500)

  asyncTest 'App.SSH should feedback data from the server', (assert) =>
    set = setupForContainer()
    cp = spinUpTestServer()

    runTest = =>
      set.fakeContainer.get = (nm)->
        return "ssh://user@0.0.0.0:2022"

      set.sshKey.privateKeyPath = "#{__dirname}/mock-ssh/id_rsa"

      gotWelcome = false
      verify = ()=>
        cp.kill('SIGTERM')
        ssh.stop()
        assert.equal(gotWelcome, true, "Expected Welcome! to be returned")
        QUnit.start()

      tm = setTimeout(=>
        verify()
      , 500)

      dataReceived = (data)=>
        if data.indexOf("Welcome!") != -1
          clearTimeout(tm)
          gotWelcome = true
          verify()
      ssh = new App.SSH(set.fakeContainer, {onData: dataReceived, restartOnExit: false})
      ssh.start()

    cp.stdout.on 'data', (data) =>
      data = data.toString('utf8')
      console.log data
      if data.indexOf('Waiting for Accept') != -1
        runTest()
    cp.stderr.on 'data', (data) =>
      console.log data.toString('utf8')
    cp.on 'exit', (code) =>
      console.log code
