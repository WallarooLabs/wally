use "collections"
use "../messages"

actor Initializer
  let _auth: AmbientAuth
  let _expected: USize
  let _connections: Connections
  var _control_identified: USize = 1
  var _data_identified: USize = 1
  // var interconnected: USize = 0
  var _initialized: USize = 0

  let _control_addrs: Map[String, (String, String)] = _control_addrs.create()
  let _data_addrs: Map[String, (String, String)] = _data_addrs.create()

  new create(auth: AmbientAuth, workers: USize, connections: Connections) =>
    _auth = auth
    _expected = workers
    _connections = connections

  be identify_control_address(worker: String, host: String, service: String) =>
    if _control_addrs.contains(worker) then
      @printf[I32](("Initializer: " + worker + " tried registering control channel twice.\n").cstring())
    else  
      @printf[I32]("Identifying control!\n".cstring())
      _control_addrs(worker) = (host, service)
      _control_identified = _control_identified + 1
      if (_control_identified == _expected) and 
        (_data_identified == _expected) then
        @printf[I32]("All worker channels identified\n".cstring())

        _initialize()      
      end
    end

  be identify_data_address(worker: String, host: String, service: String) =>
    if _control_addrs.contains(worker) then
      @printf[I32](("Initializer: " + worker + " tried registering data channel twice.\n").cstring())
    else  
      @printf[I32]("Identifying data!\n".cstring())
      _data_addrs(worker) = (host, service)
      _data_identified = _data_identified + 1
      if (_control_identified == _expected) and 
        (_data_identified == _expected) then
        @printf[I32]("All worker channels identified\n".cstring())

        _initialize()
      end
    end

  fun _initialize() =>
    let addresses = _generate_addresses_map()
    try
      let message = ChannelMsgEncoder.create_connections(addresses, _auth)
      for key in _control_addrs.keys() do
        _connections.send_control(key, message)
      end
    else
      @printf[I32]("Initializer: Error initializing workers\n".cstring())
    end

  fun _generate_addresses_map(): Map[String, Map[String, (String, String)]] val
  =>
    let map: Map[String, Map[String, (String, String)]] trn = 
      recover Map[String, Map[String, (String, String)]] end
    let control_map: Map[String, (String, String)] trn = 
      recover Map[String, (String, String)] end
    for (key, value) in _control_addrs.pairs() do
      control_map(key) = value
    end
    let data_map: Map[String, (String, String)] trn =
      recover Map[String, (String, String)] end
    for (key, value) in _data_addrs.pairs() do
      data_map(key) = value
    end

    map("control") = consume control_map
    map("data") = consume data_map
    consume map
