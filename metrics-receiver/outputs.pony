use "net"
use "buffy/messages"
use "sendence/bytes"


primitive EventTypes
  fun sinks(): String => "source-sink-metrics"
  fun boundaries(): String => "ingress-egress-metrics"
  fun steps(): String => "step-metrics"


actor MonitoringHubOutput
  let _env: Env
  let _app_name: String
  let _conn: (TCPConnection | None) = None

  new create(env: Env, app_name: String, host: String, service: String) =>
    _env = env
    _app_name = app_name
    
    try
      let auth = env.root as AmbientAuth
      let notifier: TCPConnectionNotify iso =
        recover MonitoringHubConnectNotify(env, this) end
      _conn = TCPConnection(auth, consume notifier, host, service)
      send_connect()
    else
      _env.out.print("    metrics-receiver: Couldn't get ambient authority")
    end  

/*
Connect Message:

Connect Success Response:
{"payload": {"status": "ok", "response": "connected"}}

Connect Error Response:
{"payload": {"status": "error", "response": "#{error-msg}"}}

Channel Join Message:
{"event": "phx_join", "topic": "metrics:<app-name>", "ref": null, "payload": {}}

Channel Join Message Response:
{"event": "phx_reply", "topic": "metrics:<application-name>", "ref": null, "payload": {"response": {}, "status": "ok"}}

Ingress-Egress Metrics Message:
{"event": "ingress-egress-metrics", "topic": "metrics:<app-name>", "ref": null, "payload" : "#{metrics_msg}"}

Source-Sink Metrics Message:
{"event": "source-sink-metrics", "topic": "metrics:<app-name>", "ref": null, "payload" : "#{metrics_msg}"}

Step Metrics Message:
{"event": "step-metrics", "topic": "metrics<app-name>", "ref": null, "payload" : "#{metrics_msg}"}

Reply:
{"event": "phx_reply", "topic": "metrics:<app-name>", "ref": null, "payload": {"response": {}, "status": "ok"}}
*/
  be send_connect() =>
    """
    Send a "connect" message to Monitoring Hub
    """
    if (_conn isnt None) then
      try
        _env.out.print("    metrics-receiver: Connecting...")
        let c = _conn as TCPConnection
        let message: Array[U8] iso = recover Array[U8] end
        message.append("""{"path": "/socket/tcp", "params": null}""")
        c.write(Bytes.length_encode(message))
      else
        _env.out.print("    metrics-receiver: Failed sending connect")
      end
    end
 
  be send(category: String, payload: String) =>
    _env.out.print(consume payload)

  be send_sinks(payload: String) =>
    send(EventTypes.sinks(), payload)

  be send_boundaries(payload: String) =>
    send(EventTypes.boundaries(), payload)

  be send_steps(payload: String) =>
    send(EventTypes.steps(), payload)


class MonitoringHubConnectNotify is TCPConnectionNotify
  let _env: Env
  let _output: MonitoringHubOutput
  let _framer: Framer = Framer

  new iso create(env: Env, child: DagonChild) =>
    _env = env
    _child = child

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("    dagon-child: Dagon connection accepted")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    // parse Dagon command
    for chunked in _framer.chunk(consume data).values() do
      try
        let decoded = WireMsgDecoder(consume chunked)
        match decoded
        | let m: StartMsg val =>
          _env.out.print("    dagon-child: received start message")
          _child.start()
        | let m: ShutdownMsg val =>
          _env.out.print("    dagon-child: received shutdown messages ")
         _child.shutdown()
        else
          _env.out.print("    dagon-child: Unexpected message from Dagon")
        end
      else
        _env.out.print("    dagon-child: Unable to decode message from Dagon")
      end
    end
    
  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("dagon child: server closed")
