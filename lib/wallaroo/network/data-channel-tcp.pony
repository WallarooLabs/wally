use "net"
use "time"
use "buffered"
use "collections"
use "sendence/bytes"
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

  new iso create(name: String, env: Env, auth: AmbientAuth, 
    connections: Connections, is_initializer: Bool, 
    receivers: Map[String, DataReceiver] val)
  =>
    _name = name
    _env = env
    _auth = auth
    _is_initializer = is_initializer
    _connections = connections
    _receivers = receivers    

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
    DataChannelConnectNotifier(_receivers, _env, _auth)

class DataOrigin is Origin
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _seq_translate: SeqTranslationTable = SeqTranslationTable(10)
  let _route_translate: RouteTranslationTable = RouteTranslationTable(10)
  let _origins: OriginSet = OriginSet(10)

  fun ref _hwm_get(): HighWatermarkTable =>
    _hwm
  
  fun ref _lwm_get(): LowWatermarkTable =>
    _lwm
    
  fun ref _seq_translate_get(): SeqTranslationTable =>
    _seq_translate

  fun ref _route_translate_get(): RouteTranslationTable =>
    _route_translate
  
  fun ref _origins_get(): OriginSet =>
    _origins

  // be update_watermark(route_id: U64, seq_id: U64)
  // =>
  //   //TODO: ack on TCP?
  //   None
    
class DataChannelConnectNotifier is TCPConnectionNotify
  let _receivers: Map[String, DataReceiver] val
  let _env: Env
  let _auth: AmbientAuth
  let _origin: DataOrigin tag 
  var _header: Bool = true

  new iso create(receivers: Map[String, DataReceiver] val,
    env: Env, auth: AmbientAuth) 
  =>
    _receivers = receivers    
    _env = env
    _auth = auth
    _origin = DataOrigin

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      match ChannelMsgDecoder(consume data, _auth)
      | let d: DeliveryMsg val =>
        try
          _receivers(d.from_name()).received(d)
        else
          @printf[I32]("Missing DataReceiver!\n".cstring())
        end
      | let c: ReplayCompleteMsg val =>
        try
          _receivers(c.from_name()).upstream_replay_finished()
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
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("accepted")
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    _env.out.print("incoming connected")

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
