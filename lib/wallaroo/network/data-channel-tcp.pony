use "buffered"
use "collections"
use "net"
use "time"
use "sendence/bytes"
use "sendence/wall-clock"
use "wallaroo/boundary"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

class DataChannelListenNotifier is TCPListenNotify
  let _name: String
  let _env: Env
  let _auth: AmbientAuth
  let _is_initializer: Bool
  var _host: String = ""
  var _service: String = ""
  let _connections: Connections
  let _receivers: Map[String, DataReceiver] val
  let _metrics_reporter: MetricsReporter

  new iso create(name: String, env: Env, auth: AmbientAuth,
    connections: Connections, is_initializer: Bool,
    receivers: Map[String, DataReceiver] val,
    metrics_reporter: MetricsReporter iso)
  =>
    _name = name
    _env = env
    _auth = auth
    _is_initializer = is_initializer
    _connections = connections
    _receivers = receivers
    _metrics_reporter = consume metrics_reporter

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + " data channel: listening on " + _host + ":" + _service)
      if not _is_initializer then
        let message = ChannelMsgEncoder.identify_data_port(_name, _service,
          _auth)
        _connections.send_control("initializer", message)
      end
    else
      _env.out.print(_name + "control : couldn't get local address")
      listen.close()
    end

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    DataChannelConnectNotifier(_receivers, _connections, _env, _auth,
    _metrics_reporter.clone())


class DataChannelConnectNotifier is TCPConnectionNotify
  let _receivers: Map[String, DataReceiver] val
  let _connections: Connections
  let _env: Env
  let _auth: AmbientAuth
  var _header: Bool = true
  let _timers: Timers = Timers
  let _metrics_reporter: MetricsReporter

  new iso create(receivers: Map[String, DataReceiver] val,
    connections: Connections, env: Env, auth: AmbientAuth,
    metrics_reporter: MetricsReporter iso)
  =>
    _receivers = receivers
    _connections = connections
    _env = env
    _auth = auth
    _metrics_reporter = consume metrics_reporter

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
      true
    else
      let ingest_ts = WallClock.nanoseconds() // because we received this from another worker
      let my_latest_ts = Time.nanos()

      ifdef "trace" then
        @printf[I32]("Rcvd msg on data channel\n".cstring())
      end
      match ChannelMsgDecoder(consume data, _auth)
      | let data_msg: DataMsg val =>
        try
          _metrics_reporter.step_metric(data_msg.metric_name,
            "Before receive on data channel (network time)", data_msg.metrics_id,
            data_msg.latest_ts, ingest_ts)
          _receivers(data_msg.delivery_msg.sender_name()).received(
            data_msg.delivery_msg,
            data_msg.pipeline_time_spent + (ingest_ts - data_msg.latest_ts),
            data_msg.seq_id, my_latest_ts, data_msg.metrics_id + 1, my_latest_ts)
        else
          @printf[I32]("Missing DataReceiver!\n".cstring())
        end
      | let dc: DataConnectMsg val =>
        try
          _receivers(dc.sender_name).data_connect(dc.sender_step_id)
        else
          @printf[I32]("Missing DataReceiver!\n".cstring())
        end
      | let aw: AckWatermarkMsg val =>
        _connections.ack_watermark_to_boundary(aw.sender_name, aw.seq_id)
      | let r: ReplayMsg val =>
        try
          let data_msg = r.data_msg(_auth)
          _metrics_reporter.step_metric(data_msg.metric_name,
            "Before replay receive on data channel (network time)", data_msg.metrics_id,
            data_msg.latest_ts, ingest_ts)
          _receivers(data_msg.delivery_msg.sender_name())
            .replay_received(data_msg.delivery_msg,
            data_msg.pipeline_time_spent + (ingest_ts - data_msg.latest_ts),
            data_msg.seq_id, my_latest_ts, data_msg.metrics_id + 1, my_latest_ts)
        else
          @printf[I32]("Missing DataReceiver!\n".cstring())
        end
      | let c: ReplayCompleteMsg val =>
        try
          _receivers(c.sender_name()).upstream_replay_finished()
        else
          @printf[I32]("Missing DataReceiver!\n".cstring())
        end
      | let m: SpinUpLocalTopologyMsg val =>
        _env.out.print("Received spin up local topology message!")
      | let m: UnknownChannelMsg val =>
        _env.err.print("Unknown Wallaroo data message type.")
      else
        _env.err.print("Unknown Wallaroo data message type.")
      end

      conn.expect(4)
      _header = true

      ifdef linux then
        true
      else
        false
      end
    end

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("accepted data channel connection")
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    _env.out.print("incoming connected on data channel")

// class DataSenderConnectNotifier is TCPConnectionNotify
//   let _env: Env

//   new iso create(env: Env)
//   =>
//     _env = env

//   fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
//     _env.out.print("Data sender channel received data.")
//     true

  // fun ref closed(conn: TCPConnection ref) =>
  //   _coordinator.reconnect_data(_target_name)
