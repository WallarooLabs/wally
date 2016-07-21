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
  fun _encode(id: U16, s: String, wb: WriteBuffer): Array[ByteSeq] val =>
    let s_array = s.array()
    let size = s_array.size() + 2
    wb.u32_be(size.u32())
    wb.u16_be(id)
    wb.write(s_array)
    wb.done()

  fun data(d: Stringable val, wb: WriteBuffer = WriteBuffer): 
    Array[ByteSeq] val =>
    _encode(_Data(), d.string(), wb)

  fun ready(node_name: String, wb: WriteBuffer = WriteBuffer): 
    Array[ByteSeq] val =>
    _encode(_Ready(), node_name, wb)

  fun topology_ready(node_name: String, wb: WriteBuffer = WriteBuffer): 
    Array[ByteSeq] val =>
    _encode(_TopologyReady(), node_name, wb)

  fun start(wb: WriteBuffer = WriteBuffer): 
    Array[ByteSeq] val =>
    _encode(_Start(), "", wb)

  fun shutdown(node_name: String, wb: WriteBuffer = WriteBuffer): 
    Array[ByteSeq] val =>
    _encode(_Shutdown(), node_name, wb)
    
  fun done_shutdown(node_name: String, wb: WriteBuffer = WriteBuffer): 
    Array[ByteSeq] val =>
    _encode(_DoneShutdown(), node_name, wb)
    
  fun done(node_name: String, wb: WriteBuffer = WriteBuffer): 
    Array[ByteSeq] val =>
    _encode(_Done(), node_name, wb)
    
class BufferedExternalMsgEncoder
  let _buffer: WriteBuffer

  new create(wb: WriteBuffer = WriteBuffer, chunks: USize = 0) =>
    _buffer = wb
    _buffer.reserve_chunks(chunks)

  fun ref _encode_and_add(id: U16, s: String): BufferedExternalMsgEncoder =>
    let s_array = s.array()
    let size = s_array.size() + 2
    _buffer.u32_be(size.u32())
    _buffer.u16_be(id)
    _buffer.write(s_array)
    this

  fun ref add_data(d: Stringable val): BufferedExternalMsgEncoder =>
    _encode_and_add(_Data(), d.string())

  fun ref add_ready(node_name: String): BufferedExternalMsgEncoder =>
    _encode_and_add(_Ready(), node_name)

  fun ref add_topology_ready(node_name: String): BufferedExternalMsgEncoder =>
    _encode_and_add(_TopologyReady(), node_name)

  fun ref add_start(): BufferedExternalMsgEncoder =>
    _encode_and_add(_Start(), "")

  fun ref add_shutdown(node_name: String): BufferedExternalMsgEncoder =>
    _encode_and_add(_Shutdown(), node_name)
    
  fun ref add_done_shutdown(node_name: String): BufferedExternalMsgEncoder =>
    _encode_and_add(_DoneShutdown(), node_name)
    
  fun ref add_done(node_name: String): BufferedExternalMsgEncoder =>
    _encode_and_add(_Done(), node_name)

  fun ref reserve_chunks(chunks: USize = 0) =>
    _buffer.reserve_chunks(chunks)

  fun ref done(): Array[ByteSeq] val =>
    _buffer.done()

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
    let s_len = data.size() - 2
    let s = String.from_array(rb.block(s_len))
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
