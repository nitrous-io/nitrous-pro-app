withWindow "login", ->
  moduleFor 'controller:login-window', 'Login Window Controller'

  sinon = require "sinon"

  test "signUp should open an external to config.signUpUrl", ->
    shell = window.activeRequires.shell
    config = window.activeRequires["./config"]
    sinon.stub(shell, "openExternal")
    this.subject().send("signUp")
    expect(shell.openExternal.calledWith(config.signUpUrl)).to.be.true()

  test "login should set invalidCredentials when username/password is incorrect", ->
    receivedJqxhr = null
    fkDef = {}
    fkDef.then = (res, jqxhr)=>
      receivedJqxhr = jqxhr
    jx = sinon.stub(window.$, "ajax")
    jx.returns(fkDef)

    this.subject().set("username", "us1")
    this.subject().set("password", "psword")
    this.subject().send("login")

    call = window.$.ajax.getCall(0)
    args = call.args[0]
    expect(args.type).to.equal('POST')
    expect(args.url.indexOf('/api/v0/oauth/token')).not.to.equal(-1)
    expect(args.data.grant_type).to.equal('password')
    expect(args.data.username).to.equal('us1')
    expect(args.data.password).to.equal('psword')

    expect(this.subject().get("loggingIn")).to.be.true()
    receivedJqxhr(
      status: 400
      responseJSON:
        error: "invalid_grant"
    )

    expect(this.subject().get("invalidCredentials")).to.be.true()
    expect(this.subject().get("loggingIn")).to.be.false()

    jx.restore()

  test "login should fail() on jqxhr otherwise", ->
    receivedJqxhr = null
    fkDef = {}
    fkDef.then = (res, jqxhr)=>
      receivedJqxhr = jqxhr
    jx = sinon.stub(window.$, "ajax")
    jx.returns(fkDef)

    this.subject().send("login")

    call = window.$.ajax.getCall(0)
    args = call.args[0]

    f = sinon.stub(this.subject(), "fail")

    receivedJqxhr(j: true)
    expect(this.subject().fail.calledWith(j: true)).to.be.true()

    jx.restore()
    f.restore()

  test "login should set the access-token on local storage and fetchUser()", ->
    receivedRes = null
    fkDef = {}
    fkDef.then = (res, jqxhr)=>
      receivedRes = res
    jx = sinon.stub(window.$, "ajax")
    jx.returns(fkDef)

    this.subject().send("login")

    call = window.$.ajax.getCall(0)
    args = call.args[0]

    f = sinon.stub(this.subject(), "fetchUser")
    sI = sinon.stub(window.localStorage, "setItem")
    receivedRes(
      access_token: "Tok3n"
    )

    expect(this.subject().fetchUser.called).to.be.true()
    expect(window.localStorage.setItem.calledWith("access-token", "Tok3n")).to.be.true()

    jx.restore()
    f.restore()
    sI.restore()
