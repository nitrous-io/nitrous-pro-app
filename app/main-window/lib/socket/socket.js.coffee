App.Socket = Em.Object.extend Em.Evented,
  url: null

  init: ->
    @_super.apply this, arguments
    @_conn = conn = new App.SocketConnection # not using @set to reduce overhead
    conn.onbeforeopen   = => @willOpen()
    conn.onopen    = (ev) => @didOpen(ev)
    conn.onmessage = (ev) => @didReceiveMessage(ev)
    conn.onerror   = (ev) => @didFail(ev)
    conn.onclose   = (ev) => @didClose(ev)

  connect: ->
    @_conn.open()

  disconnect: ->
    @_conn?.close()
    @_conn = undefined

  send: (data) ->
    @_conn?.send(data)

  willOpen: (ev) ->
    @_conn.url = @get('url')
    @trigger 'beforeopen', ev

  didOpen: (ev) ->
    @trigger 'open', ev

  didReceiveMessage: (ev) ->
    @trigger 'message', ev.data

  didFail: (ev) ->
    @trigger 'error', ev

  didClose: (ev) ->
    @trigger 'close', ev
