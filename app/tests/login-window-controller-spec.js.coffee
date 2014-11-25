withWindow "login", ->
  moduleFor 'controller:login-window', 'Login Window Controller'

  sinon = require "sinon"

  test "signUp should open an external to config.signUpUrl", ->
    shell = window.activeRequires.shell
    config = window.activeRequires["./config"]
    sinon.stub(shell, "openExternal")
    this.subject().send("signUp")
    expect(shell.openExternal.calledWith(config.signUpUrl)).to.be.true();