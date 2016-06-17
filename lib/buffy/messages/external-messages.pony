use "osc-pony"
use "sendence/bytes"
use "net"

primitive _Data                                 fun apply(): U16 => 1
primitive _Ready                                fun apply(): U16 => 2
primitive _TopologyReady                        fun apply(): U16 => 3
primitive _Start                                fun apply(): U16 => 4
primitive _Shutdown                             fun apply(): U16 => 5
primitive _DoneShutdown                         fun apply(): U16 => 6
primitive _Done                                 fun apply(): U16 => 7
primitive _Unknown                              fun apply(): U16 => 8

primitive ExternalMsgEncoder
  fun _encode(id: U16, s: String): Array[ByteSeq] val =>
    let wb = WriteBuffer
    let s_array = s.array()
    let size = s_array.size() + 6
    wb.u32_be(size.u32())
    wb.u16_be(id)
    wb.u32_be(s.size().u32())
    wb.write(s_array)
    wb.done()

  fun data(d: Stringable val): Array[ByteSeq] val =>
    _encode(_Data(), d.string())

  fun ready(node_name: String): Array[ByteSeq] val =>
    _encode(_Ready(), node_name)

  fun topology_ready(node_name: String): Array[ByteSeq] val =>
    _encode(_TopologyReady(), node_name)

  fun start(): Array[ByteSeq] val =>
    _encode(_Start(), "")

  fun shutdown(node_name: String): Array[ByteSeq] val =>
    _encode(_Shutdown(), node_name)
    
  fun done_shutdown(node_name: String): Array[ByteSeq] val =>
    _encode(_DoneShutdown(), node_name)
    
  fun done(node_name: String): Array[ByteSeq] val =>
    _encode(_Done(), node_name)
    
primitive ExternalMsgDecoder
  fun apply(data: Array[U8] val): ExternalMsg val ? =>
    match _decode(data)
    | (_Data(), let s: String) =>
      ExternalDataMsg(s)
    | (_Ready(), let s: String) =>
      ExternalReadyMsg(s)
    | (_TopologyReady(), let s: String) =>
      ExternalTopologyReadyMsg(s)
    | (_Start(), let s: String) =>
      ExternalStartMsg   
    | (_Shutdown(), let s: String) =>
      ExternalShutdownMsg(s)
    | (_DoneShutdown(), let s: String) =>
      ExternalDoneShutdownMsg(s)
    | (_Done(), let s: String) =>
      ExternalDoneMsg(s)
    else
      error
    end

  fun _decode(data: Array[U8] val): (U16, String) ? =>
    let rb = ReadBuffer
    rb.append(data)
    let id = rb.u16_be()
    let s_len = rb.u32_be()
    let s = String.from_array(rb.block(s_len.usize()))
    (id, s) 

trait val ExternalMsg

class ExternalDataMsg is ExternalMsg
  let data: String

  new val create(d: String) =>
    data = d

class ExternalReadyMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

class ExternalTopologyReadyMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

primitive ExternalStartMsg is ExternalMsg

class ExternalShutdownMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

class ExternalDoneShutdownMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

class ExternalDoneMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n
