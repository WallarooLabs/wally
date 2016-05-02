use "net"
use "options"
use "osc-pony"

use "messages"
use "sendence/tcp"


actor Main
  let _env: Env
  var _node_name: String = "0"
  var _phone_home_host: String = ""
  var _phone_home_service: String = "8080"
  var _conn: (TCPConnection | None) = None
  
  new create(env: Env) =>
    _env = env
    var options = Options(env)
    var args = options.remaining()

    options
      .add("name", "n", StringArgument)
      .add("phone_home_host", "h", StringArgument)
      .add("phone_home_service", "p", StringArgument)

    for option in options do
      match option
      | ("name", let arg: String) => _node_name = arg
      | ("phone_home_host", let arg: String) => _phone_home_host = arg
      | ("phone_home_service", let arg: String) => _phone_home_service = arg
      end
    end

    _env.out.print("dagon-child: name: " + _node_name)
    _env.out.print("dagon-child: phone_home_host: " + _phone_home_host)
    _env.out.print("dagon-child: phone_home_service: " + _phone_home_service)

    try
      let auth = env.root as AmbientAuth
      let ph_host = _phone_home_host
      let ph_service = _phone_home_service
      let notifier: TCPConnectionNotify iso =
        recover HomeConnectNotify(env, this) end
      _conn = TCPConnection(auth, consume notifier, ph_host, ph_service)
        _send_ready()
    else
      _env.out.print("dagon-child: Couldn't get ambient authority")
    end   
    
  fun ref _send_ready() =>
    """
    Send a "ready" message back to Dagon.
    """
    if (_conn isnt None) then
      try
        _env.out.print("dagon-child: Sending ready...")
        let c = _conn as TCPConnection
        let message = WireMsgEncoder.ready(_node_name)
        c.write(message)
      else
        _env.out.print("dagon-child: Failed sending ready")
      end
    end

  fun ref _send_done_shutdown() =>
    """
    Send a "done_shutdown" message back to Dagon.
    """
     if (_conn isnt None) then
      try
        _env.out.print("dagon-child: Sending done_shutdown..")
        let c = _conn as TCPConnection
        let message = WireMsgEncoder.done_shutdown(_node_name)
        c.write(message)
      else
        _env.out.print("dagon-child: Failed sending done_shutdown")
      end
    end   
    
  be start() =>
    _env.out.print("dagon-child: Starting...")

  be shutdown() =>
    if (_conn isnt None) then
      _env.out.print("dagon-child: Shutting down...")
      try
        _send_done_shutdown()
        let c = _conn as TCPConnection
        c.dispose()
        _env.out.print("dagon-child: disposed of tcp connection")
      else
        _env.out.print("dagon-child: Failed closing connection")
      end
    end

class HomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _child: Main
  let _framer: Framer = Framer

  new iso create(env: Env, child: Main) =>
    _env = env
    _child = child

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("dagon-child: Dagon connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _env.out.print("dagon-child: received from Dagon")
    // parse Dagon command
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = WireMsgDecoder(consume chunked)
        match decoded
        | let m: StartMsg val =>
          _env.out.print("dagon-child: received start message")
          _child.start()
        | let m: ShutdownMsg val =>
          _env.out.print("dagon-child: received shutdown messages ")
         _child.shutdown()
        else
          _env.out.print("Unexpected message from Dagon")
        end
      else
        _env.out.print("Unable to decode message from Dagon")
      end
    end

    
  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon child: server closed")
