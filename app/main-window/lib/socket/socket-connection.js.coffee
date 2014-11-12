class App.SocketConnection
  ws: null
  url: undefined
  protocols: undefined
  retries: 0

  constructor: (url, protocols) ->
    @url = url
    @protocols = protocols
    @retries = 0

  open: (nobeforeopen) ->
    if ws = @ws
      ws.close()
      ws.onopen = null
      ws.onclose = null
      ws.onerror = null
      ws.onmessage = null
      ws.removeEventListener 'open',  @_onopen,  false
      ws.removeEventListener 'close', @_onclose, false

    unless nobeforeopen
      @onbeforeopen()

    unless @url
      @ws = null
      return

    @ws = ws = if @protocols
      new WebSocket(@url, @protocols)
    else
      new WebSocket(@url)
    ws.onopen    = (evt) => @onopen(evt)
    ws.onclose   = (evt) => @onclose(evt)
    ws.onerror   = (evt) => @onerror(evt)
    ws.onmessage = (evt) => @onmessage(evt)

    @_onopen ||= =>
      @retries = 0

    @_onclose ||= =>
      if @_closeInvoked
        @_closeInvoked = false
        return
      @retry()

    ws.addEventListener 'open',  @_onopen,  false
    ws.addEventListener 'close', @_onclose, false

  retry: ->
    delay = if @retries <= 5
      1000
    else if @retries <= 10
      2500
    else if @retries > 10
      5000
    window.setTimeout(=>
      @open()
    , delay)
    @retries += 1

  send: ->
    @ws.send.apply(@ws, arguments)

  close: ->
    @_closeInvoked = true
    @ws?.close?.apply(@ws, arguments)

  onbeforeopen: ->
  onopen: ->
  onclose: ->
  onmessage: ->
  onerror: ->

Object.defineProperties App.SocketConnection.prototype,
  binaryType     : { get: -> @ws?.binaryType }
  bufferedAmount : { get: -> @ws?.bufferedAmount }
  extensions     : { get: -> @ws?.extensions }
  protocol       : { get: -> @ws?.protocol }
  readyState     : { get: -> @ws?.readyState }
