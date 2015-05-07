LS_KEY = "SSHPortForwarder"

startedInstances = []
rangeRegexp = /(\d+)-(\d+)/

klass = App.SSHPortForwarder = Em.Object.extend
  container: null
  ports: null
  enabled: false

  enabledChanged: (->
    if @get 'enabled'
      @start()
    else
      @stop()
  ).observes 'enabled'

  portPairs: (->
    set = []
    @get('ports').forEach (r,l)=>
      if l.match(rangeRegexp)
        set.push {local: l, remote: l}
      else
        set.push {local: parseInt(l), remote: parseInt(r)}
    set.sort (a,b)->
      a - b
  ).property 'ports'

  init: ->
    @_super.apply this, arguments
    @lastPortForwarded = null

  writeSettings: (->
    return if @loading
    data = {}
    data.enabled = @get 'enabled'
    data.ports = []
    @get('ports').forEach (r,l)=>
      data.ports.push("#{l}:#{r}")

    window.localStorage.setItem "#{LS_KEY}.#{@get('container.id')}", JSON.stringify(data)
  ).observes 'enabled', 'ports'

  loadSettings: ->
    return if @loading || @loaded

    @loading = true
    @set 'ports', new Map()

    data = window.localStorage.getItem "#{LS_KEY}.#{@get('container.id')}"
    if data
      deser = JSON.parse data
      if deser.ports
        deser.ports.forEach (p)=>
          @addPort(p)
      @set('enabled', deser.enabled || false)

    @loading = false
    @loaded = true

  addPort: (port)->
    port = port.toString()
    ports = @get 'ports'
    return if ports.get port
    [local, remote] = port.split ':'
    if parseInt(local) < 1024
      window.alert "Port #{local} is reserved by your system"
      return
    if m = local.match(rangeRegexp)
      remote = local
      start = m[1]
      end = m[2]
      if end <= start
        window.alert "#{end} must be greater than #{start}"
        return
      if start < 1024
        window.alert "Port #{start} is reserved by your system"
        return
    else if isNaN(parseInt(local)) || (remote && isNaN(parseInt(remote)))
      return
    else
      local = parseInt(local).toString()
      if remote
        remote = parseInt(remote).toString()
      else
        remote = local
    ports.set(local, remote)
    @notifyPropertyChange 'ports'
    @restart()

  removePort: (port)->
    port = port.toString()
    [local, remote] = port.split ':'
    ports = @get 'ports'
    ports.delete local
    @notifyPropertyChange 'ports'
    @restart()

  start: ->
    @stop() if @ssh
    args = []
    @get('ports').forEach (r,l)=>
      if m = l.match(rangeRegexp)
        for i in [parseInt(m[1])...parseInt(m[2])] by 1
          args.push('-L', "#{i}:127.0.0.1:#{i}")
      else
        args.push('-L', "#{l}:127.0.0.1:#{r}")

    if args.length >= 15000
      @set 'enabled', false
      window.alert "Port range is too high, please specify smaller ranges"
      return

    if args.length == 0
      @set 'enabled', false
      window.alert "Please add some ports to enable port forwarding"
      return

    @ssh = new App.SSH(@container,
      onData: (data)=>
        @handleData(data)
      args: args)

    @ssh.start()
    startedInstances.push this

  handleData: (data)->
    data.split(/\r?\n/).forEach (ln)=>
      if ln.match(/select:\s+Invalid\s+argument/)
        window.alert("Port range is too high, please specify smaller ranges.")
        @set 'enabled', false

      forwarding = ln.match(/Local\s+forwarding\s+listening\s+on\s+127.0.0.1\s+port\s+(\d+)/)
      if forwarding
        @lastPortForwarded = forwarding[1]

      inUse = ln.match(/Address\s+already\s+in\s+use/)
      if @lastPortForwarded && inUse
        # the port may be in a range, in which case we silently ignore
        if @get('ports').has(@lastPortForwarded)
          window.alert("The port #{@lastPortForwarded} is being used by your computer. Please pick another port.")
          @removePort @lastPortForwarded
          @set 'enabled', false

  stop: ->
    if @ssh
      @ssh.stop()
      @ssh = null

    index = startedInstances.indexOf(this)
    startedInstances.splice(index, 1) if index != -1

  restart: ->
    return unless @ssh
    @stop()
    @start()

klass.stopAll = ->
  known = startedInstances.slice 0
  known.forEach (inst) ->
    inst.stop()
  startedInstances = []
