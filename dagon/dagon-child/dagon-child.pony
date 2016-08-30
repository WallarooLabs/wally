use "net"
use "options"
use "time"
use "sendence/messages"
use "sendence/tcp"


actor Main
  
  new create(env: Env) =>
    var options = Options(env.args)
    var args = options.remaining()
    var node_name: String = ""
    var phone_home: String = ""
    var is_leader: Bool = false
    var phone_home_host: String = ""
    var phone_home_service: String = ""
    options
      .add("name", "n", StringArgument)
      .add("phone-home", "h", StringArgument)
      .add("leader", "l", None)

    for option in options do
      match option
      | ("name", let arg: String) => node_name = arg
      | ("phone-home", let arg: String) => phone_home = arg
      | ("leader", let arg: None) => is_leader = true
      else
        env.out.print("unknown option")
      end
    end
    env.out.print("\t" + node_name + ": name: " + node_name)
    env.out.print("\t" + node_name + ": phone-home: " + phone_home)
    if phone_home != "" then
      let ph_addr = phone_home.split(":")
      try
        phone_home_host = ph_addr(0)
        phone_home_service = ph_addr(1)
      end
    end
    env.out.print("\t" + node_name + ": phone_home_host: " + phone_home_host)
    env.out.print("\t" + node_name + ": phone_home_service: " + phone_home_service)
    DagonChild(env, node_name, phone_home_host, phone_home_service)

    
actor DagonChild
  let _env: Env
  let node_name: String
  var _conn: (TCPConnection | None) = None

  
  new create(env: Env, node_name': String, host: String, service:String) =>
    _env = env
    node_name = node_name'

    try
      let auth = env.root as AmbientAuth
      let notifier: TCPConnectionNotify iso =
        recover HomeConnectNotify(env, node_name', this) end
      _conn = TCPConnection(auth, consume notifier, host, service)
      send_ready()
      send_topology_ready()
    else
      _env.out.print("\t" + node_name + ": Couldn't get ambient authority")
    end   
    
  be send_ready() =>
    """
    Send a "ready" message back to Dagon.
    """
    if (_conn isnt None) then
      try
        _env.out.print("\t" + node_name + ": Sending ready...")
        let c = _conn as TCPConnection
        let message = ExternalMsgEncoder.ready(node_name)
        c.writev(message)
      else
        _env.out.print("\t" + node_name + ": Failed sending ready")
      end
    end

  be send_topology_ready() =>
    """
    Send a "ready" message back to Dagon.
    """
    if (_conn isnt None) then
      try
        _env.out.print("\t" + node_name + ": Sending topology ready...")
        let c = _conn as TCPConnection
        let message = ExternalMsgEncoder.topology_ready(node_name)
        c.writev(message)
      else
        _env.out.print("\t" + node_name + ": Failed sending topology ready")
      end
    end    

  be send_done() =>
    """
    Send a "done" message back to Dagon.
    """
    if (_conn isnt None) then
      try
        _env.out.print("\t" + node_name + ": Sending done...")
        let c = _conn as TCPConnection
        let message = ExternalMsgEncoder.done(node_name)
        c.writev(message)
      else
        _env.out.print("\t" + node_name + ": Failed sending done")
      end
    end
    
  be send_done_shutdown() =>
    """
    Send a "done_shutdown" message back to Dagon.
    """
     if (_conn isnt None) then
      try
        _env.out.print("\t" + node_name + ": Sending done_shutdown..")
        let c = _conn as TCPConnection
        let message = ExternalMsgEncoder.done_shutdown(node_name)
        c.writev(message)
      else
        _env.out.print("\t" + node_name + ": Failed sending done_shutdown")
      end
    end   
    
  be start() =>
    _env.out.print("\t" + node_name + ": Starting...")
    // fake some work here
    let timers = Timers
    let timer = Timer(FakeWork(_env, node_name, this, 10), 0, 10_000_000_000)
    timers(consume timer)

    
  be shutdown() =>
    if (_conn isnt None) then
      _env.out.print("\t" + node_name + ": Shutting down " + node_name)
      try
        let c = _conn as TCPConnection
        c.dispose()
        _env.out.print("\t" + node_name + ": disposed of tcp connection")
      else
        _env.out.print("\t" + node_name + ": Failed closing connection")
      end
    end

    
class HomeConnectNotify is TCPConnectionNotify
  let _env: Env
  let _child: DagonChild
  let node_name: String
  let _framer: Framer = Framer

  new iso create(env: Env, node_name':String, child: DagonChild) =>
    _env = env
    _child = child
    node_name = node_name'

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("\t" + node_name + ": Dagon accepted connection")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    // parse Dagon command
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = ExternalMsgDecoder(consume chunked)
        match decoded
        | let m: ExternalStartMsg val =>
          _env.out.print("\t" + node_name + ": received start message")
          _child.start()
        | let m: ExternalShutdownMsg val =>
         _env.out.print("\t" + node_name + ": received shutdown messages ")
         _child.send_done_shutdown()
         _child.shutdown()
        else
          _env.out.print("\t" + node_name + ": Unexpected message from Dagon")
        end
      else
        _env.out.print("\t" + node_name + ": Unable to decode message from Dagon")
      end
    end
    true
    
  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("\t" + node_name + ": server closed connection")


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
    _env.out.print("\t" + _node_name + ": " + c.string() + " ...working...")
    if c > _limit then
      false
    else
      true
    end

  fun ref cancel(timer: Timer) =>
    _child.send_done()
    _child.send_done_shutdown()
    _child.shutdown()
