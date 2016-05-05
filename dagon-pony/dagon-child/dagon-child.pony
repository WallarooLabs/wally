use "net"
use "options"
use "osc-pony"
use "time"
use "messages"
use "sendence/tcp"


actor Main
  
  new create(env: Env) =>
    var options = Options(env)
    var args = options.remaining()
    var node_name: String = ""
    var host: String = ""
    var service: String = ""
    options
      .add("node_name", "n", StringArgument)
      .add("phone_home_host", "h", StringArgument)
      .add("phone_home_service", "p", StringArgument)

    for option in options do
      match option
      | ("node_name", let arg: String) => node_name = arg
      | ("phone_home_host", let arg: String) => host = arg
      | ("phone_home_service", let arg: String) => service = arg
      end
    end
    env.out.print("dagon-child: node_name: " + node_name)
    env.out.print("dagon-child: phone_home_host: " + host)
    env.out.print("dagon-child: phone_home_service: " + service)
    DagonChild(env, node_name, host, service)

    
actor DagonChild
  let _env: Env
  let _node_name: String
  var _conn: (TCPConnection | None) = None

  
  new create(env: Env, node_name: String, host: String, service:String) =>
    _env = env
    _node_name = node_name

    try
      let auth = env.root as AmbientAuth
      let notifier: TCPConnectionNotify iso =
        recover HomeConnectNotify(env, this) end
      _conn = TCPConnection(auth, consume notifier, host, service)
      send_ready()
    else
      _env.out.print("dagon-child: Couldn't get ambient authority")
    end   
    
  be send_ready() =>
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

  be send_done() =>
    """
    Send a "done" message back to Dagon.
    """
    if (_conn isnt None) then
      try
        _env.out.print("dagon-child: Sending done...")
        let c = _conn as TCPConnection
        let message = WireMsgEncoder.done(_node_name)
        c.write(message)
      else
        _env.out.print("dagon-child: Failed sending done")
      end
    end
    
  be send_done_shutdown() =>
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
    // fake some work here
    let timers = Timers
    let timer = Timer(FakeWork(_env, _node_name, this, 10), 0, 1_000_000_000)
    timers(consume timer)

    
  be shutdown() =>
    if (_conn isnt None) then
      _env.out.print("dagon-child: Shutting down " + _node_name)
      try
        send_done_shutdown()
        let c = _conn as TCPConnection
        c.dispose()
        _env.out.print("dagon-child: disposed of tcp connection")
      else
        _env.out.print("dagon-child: Failed closing connection")
      end
    end

    
class HomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _child: DagonChild
  let _framer: Framer = Framer

  new iso create(env: Env, child: DagonChild) =>
    _env = env
    _child = child

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("dagon-child: Dagon connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
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
          _env.out.print("dagon-child: Unexpected message from Dagon")
        end
      else
        _env.out.print("dagon-child: Unable to decode message from Dagon")
      end
    end
    
  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon child: server closed")


class FakeWork is TimerNotify  
  let _env: Env
  var _counter: U64
  let _limit: U64
  let _node_name: String
  let _child: DagonChild

  new iso create(env: Env, node_name: String, child: DagonChild, limit: U64) =>
    _counter = 0
    _env = env
    _node_name = node_name
    _child = child
    _limit = limit

  fun ref _next(): U64 =>
    _counter = _counter + 1
    _counter

  fun ref apply(timer: Timer, count: U64): Bool =>
    let c = _next()
    _env.out.print(_node_name + ": " + c.string())
    if c > _limit then
      false
    else
      true
    end

  fun ref cancel(timer: Timer) =>
    _child.send_done()
