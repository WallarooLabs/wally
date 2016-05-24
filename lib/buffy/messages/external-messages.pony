use "osc-pony"
use "sendence/bytes"

primitive _Data                                 fun apply(): String => "/1"
primitive _Ready                                fun apply(): String => "/2"
primitive _TopologyReady                        fun apply(): String => "/3"
primitive _Start                                fun apply(): String => "/4"
primitive _Shutdown                             fun apply(): String => "/5"
primitive _DoneShutdown                         fun apply(): String => "/6"
primitive _Done                                 fun apply(): String => "/7"
primitive _Unknown                              fun apply(): String => "/8"

primitive ExternalMsgEncoder
  fun data(d: Stringable val): Array[U8] val =>
    let osc = OSCMessage(_Data(),
      recover
        [as OSCData val: OSCString(d.string())]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun ready(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_Ready(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun topology_ready(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_TopologyReady(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun start(): Array[U8] val =>
    let osc = OSCMessage(_Start(), recover Arguments end)
    Bytes.length_encode(osc.to_bytes())

  fun shutdown(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_Shutdown(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun done_shutdown(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_DoneShutdown(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

  fun done(node_name: String): Array[U8] val =>
    let osc = OSCMessage(_Done(),
      recover
        [as OSCData val: OSCString(node_name)]
      end)
    Bytes.length_encode(osc.to_bytes())

primitive ExternalMsgDecoder
  fun apply(data: Array[U8] val): ExternalMsg val ? =>
    let msg = OSCDecoder.from_bytes(data) as OSCMessage val
    match msg.address
    | _Data() =>
      ExternalDataMsg(msg)
    | _Ready() =>
      ExternalReadyMsg(msg)
    | _TopologyReady() =>
      ExternalTopologyReadyMsg(msg)
    | _Start() =>
      ExternalStartMsg
    | _Shutdown() =>
      ExternalShutdownMsg(msg)
    | _DoneShutdown() =>
      ExternalDoneShutdownMsg(msg)
    | _Done() =>
      ExternalDoneMsg(msg)
    else
      error
    end

trait val ExternalMsg

class ExternalDataMsg is ExternalMsg
  let data: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let d: OSCString val => data = d.value()
    else
      error
    end


class ExternalReadyMsg is ExternalMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

class ExternalTopologyReadyMsg is ExternalMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

primitive ExternalStartMsg is ExternalMsg

class ExternalShutdownMsg is ExternalMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

class ExternalDoneShutdownMsg is ExternalMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

class ExternalDoneMsg is ExternalMsg
  let node_name: String

  new val create(msg: OSCMessage val) ? =>
    match msg.arguments(0)
    | let n: OSCString val =>
      node_name = n.value()
    else
      error
    end

class ExternalUnknownMsg is ExternalMsg
  let data: Array[U8] val

  new val create(d: Array[U8] val) =>
    data = d
