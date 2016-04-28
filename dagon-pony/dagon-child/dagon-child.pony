use "net"
use "options"
use "osc-pony"

use "../../buffy-pony/messages"


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

    _env.out.print("name: " + _node_name)
    _env.out.print("phone_home_host: " + _phone_home_host)
    _env.out.print("phone_home_service: " + _phone_home_service)

    try
      let auth = env.root as AmbientAuth
      let ph_host = _phone_home_host
      let ph_service = _phone_home_service
      let notifier: TCPConnectionNotify iso =
        recover HomeConnectNotify(env, this) end
      _conn = TCPConnection(auth, consume notifier, ph_host, ph_service)
        _send_ready()
    else
      _env.out.print("Couldn't get ambient authority")
    end   
    
  fun ref _send_ready() =>
    """
    Send a "ready" message back to Dagon.
    """
    if (_conn isnt None) then
      try
        _env.out.print("Sending ready...")
        let c = _conn as TCPConnection
        let message = TCPMessageEncoder.ready(_node_name)
        c.write(message)
      else
        _env.out.print("Failed sending ready")
      end
    end
    
  be start() =>
    _env.out.print("Starting...")

  be shutdown() =>
    if (_conn isnt None) then
      _env.out.print("Shutting down...")
      try
        let c = _conn as TCPConnection
        c.dispose()
      else
        _env.out.print("Failed closing connection")
      end
    end

class HomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _child: Main

  new iso create(env: Env, child: Main) =>
    _env = env
    _child = child

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("dagon child: phone home connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _env.out.print("dagon child: received from phone home")
    // parse Dagon command
    try
      let msg: TCPMsg val = TCPMessageDecoder(consume data)
      match msg
      | let m: StartMsg val    => _child.start()
      | let m: ShutdownMsg val => _child.shutdown()
      else
        _env.err.print("Error decoding incoming message.")
      end
    else
      _env.err.print("Error decoding incoming message.")
    end
    
  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon child: server closed")
