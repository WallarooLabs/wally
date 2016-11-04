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
    DataChannelConnectNotifier(_receivers, _connections, _env, _auth)

    
class DataChannelConnectNotifier is TCPConnectionNotify
  let _receivers: Map[String, DataReceiver] val
  let _connections: Connections
  let _env: Env
  let _auth: AmbientAuth
  var _header: Bool = true

  new iso create(receivers: Map[String, DataReceiver] val,
    connections: Connections, env: Env, auth: AmbientAuth) 
  =>
    _receivers = receivers
    _connections = connections  
    _env = env
    _auth = auth

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      @printf[I32]("!!Got msg on datachannel\n".cstring())
      match ChannelMsgDecoder(consume data, _auth)
      | let data_msg: DataMsg val =>
        let seq_id = data_msg.seq_id
        try
          _receivers(data_msg.delivery_msg.sender_name()).received(data_msg.delivery_msg,
            seq_id)
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
          let delivery_msg = data_msg.delivery_msg

          _receivers(delivery_msg.sender_name())
            .replay_received(delivery_msg, data_msg.seq_id)              
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
