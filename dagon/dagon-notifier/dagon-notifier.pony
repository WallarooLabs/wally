use "net"
use "sendence/messages"
use "sendence/options"
use "sendence/tcp"
use "wallaroo/fail"

actor Main
  new create(env: Env) =>
    var options = Options(env.args)
    var args = options.remaining()
    var d_arg: (Array[String] | None) = None
    var m_arg: (String | None) = None
    var required_args_are_present = true

    options
      .add("dagon-addr", "d", StringArgument)
      .add("msg-type", "m", StringArgument)

    try
      for option in options do
        match option
        | ("dagon-addr", let arg: String) => d_arg = arg.split(":")
        | ("msg-type", let arg: String) => m_arg = arg
        end
      end

      if d_arg is None then
        env.err.print("Must supply required '--dagon-addr' argument")
        required_args_are_present = false
      else
        if (d_arg as Array[String]).size() != 2 then
          env.err.print(
            "'--dagon-addr' argument should be in format: 127.0.0.1:8000'")
          required_args_are_present = false
        end
      end

      if m_arg is None then
        env.err.print("Must also supply required '--msg-type' argument")
        required_args_are_present = false
      end

      if required_args_are_present then
        try
          let msg_type = m_arg as String
          let dagon_addr = d_arg as Array[String]
          DagonNotifier(env, msg_type, dagon_addr(0), dagon_addr(1))
        end
      else
        env.err.print("Required arguments were not supplied")
      end
    end


actor DagonNotifier
  let _env: Env
  let msg_type: String
  let dagon_host: String
  let dagon_service: String
  var _conn: (TCPConnection | None) = None

  new create(env: Env, msg_type': String, dagon_host': String, dagon_service': String) =>
    _env = env
    msg_type = msg_type'
    dagon_host = dagon_host'
    dagon_service = dagon_service'

    try
      let auth = env.root as AmbientAuth
      let notifier: TCPConnectionNotify iso =
        recover DagonNotify(env, this) end
      _conn = TCPConnection(auth, consume notifier, dagon_host, dagon_service)
      send_msg()
    else
      _env.out.print("Couldn't get ambient authority")
    end

  be send_msg() =>
    """
    Send provided message to Dagon.
    """
    if (_conn isnt None) then
      try
        _env.out.print("Sending msg type: " + msg_type)
        let c = _conn as TCPConnection
        match msg_type
        | "StartGilesSenders" =>
          let message = ExternalMsgEncoder.start_giles_senders()
          c.writev(message)
        else
          _env.out.print("Unable to encode msg type: " + msg_type)
          error
        end
      else
        _env.out.print("Failed sending msg type: " + msg_type)
      end
    end

  be shutdown() =>
    if (_conn isnt None) then
      _env.out.print("Shutting down")
      try
        let c = _conn as TCPConnection
        c.dispose()
        _env.out.print("Disposed of tcp connection")
      else
        _env.out.print("Failed closing connection")
      end
    end

class DagonNotify is TCPConnectionNotify
  let _env: Env
  let _notifier: DagonNotifier
  let _framer: Framer = Framer

  new iso create(env: Env, notifier: DagonNotifier) =>
    _env = env
    _notifier = notifier

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("Dagon accepted connection")

  fun ref connect_failed(conn: TCPConnection ref) =>
    Fail()

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    // parse Dagon command
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = ExternalMsgDecoder(consume chunked)
        match decoded
        | let m: ExternalGilesSendersStartedMsg val =>
          _env.out.print("Giles Senders started")
          _notifier.shutdown()
        else
          _env.out.print("Unexpected message from Dagon")
        end
      else
        _env.out.print("Unable to decode message from Dagon")
      end
    end
    true

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("Server closed connection")
