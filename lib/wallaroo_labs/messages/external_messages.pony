/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "buffered"
use "collections"
use "net"

primitive _Data                                 fun apply(): U16 => 1
primitive _Ready                                fun apply(): U16 => 2
primitive _TopologyReady                        fun apply(): U16 => 3
primitive _Start                                fun apply(): U16 => 4
primitive _Shutdown                             fun apply(): U16 => 5
primitive _DoneShutdown                         fun apply(): U16 => 6
primitive _Done                                 fun apply(): U16 => 7
primitive _Unknown                              fun apply(): U16 => 8
primitive _StartGilesSenders                    fun apply(): U16 => 9
primitive _GilesSendersStarted                  fun apply(): U16 => 10
primitive _Print                                fun apply(): U16 => 11
primitive _RotateLog                            fun apply(): U16 => 12
primitive _CleanShutdown                        fun apply(): U16 => 13
primitive _Shrink                               fun apply(): U16 => 14


primitive ExternalMsgEncoder
  fun _encode(id: U16, s: String, wb: Writer): Array[ByteSeq] val =>
    let s_array = s.array()
    let size = s_array.size()
    wb.u32_be(1 + 2 + 4 + size.u32())
    wb.u8(1) // _encode serialization type tag
    wb.u16_be(id)
    wb.u32_be(size.u32())
    wb.write(s_array)
    wb.done()

  fun _encode_shrink(id: U16, query: Bool, node_names: Array[String],
    num_nodes: U64, wb: Writer): Array[ByteSeq] val
  =>
    var num_bytes: U32 = 0

    for n in node_names.values() do
      num_bytes = num_bytes + 4 + U32.from[USize](n.size())
    end

    wb.u32_be(1 + 2 + 1 + 4 + num_bytes + 4)
    wb.u8(2) // _encode serialization type tag
    wb.u16_be(id)
    wb.u8(if query is true then 1 else 0 end)
    wb.u32_be(node_names.size().u32())
    for n in node_names.values() do
      let n_array = n.array()
      let size = n_array.size()
      wb.u32_be(size.u32())
      wb.write(n_array)
    end
    wb.u32_be(num_nodes.u32())
    wb.done()

  fun data(d: Stringable val, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_Data(), d.string(), wb)

  fun ready(node_name: String, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_Ready(), node_name, wb)

  fun topology_ready(node_name: String, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_TopologyReady(), node_name, wb)

  fun start(wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_Start(), "", wb)

  fun shutdown(node_name: String, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_Shutdown(), node_name, wb)

  fun done_shutdown(node_name: String, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_DoneShutdown(), node_name, wb)

  fun done(node_name: String, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_Done(), node_name, wb)

  fun start_giles_senders(wb: Writer = Writer):
    Array[ByteSeq] val
  =>
      _encode(_StartGilesSenders(), "", wb)

  fun senders_started(wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_GilesSendersStarted(), "", wb)

  fun print_message(message: String, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_Print(), message, wb)

  fun rotate_log(worker_name: String, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_RotateLog(), worker_name, wb)

  fun clean_shutdown(msg: String = "", wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_CleanShutdown(), msg, wb)

  fun shrink(query: Bool, node_names: Array[String] = Array[String],
    num_nodes: U64 = 0, wb: Writer = Writer): Array[ByteSeq] val
  =>
    if (query is true) then
      _encode_shrink(_Shrink(), true, Array[String], 0, wb)
    else
      _encode_shrink(_Shrink(), false, node_names, num_nodes, wb)
    end

class BufferedExternalMsgEncoder
  let _buffer: Writer

  new create(wb: Writer = Writer, chunks: USize = 0) =>
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
    """
    Decode an ExternalMsg that was been encoded by ExternalMsgEncoder.

    NOTE: ExternalMsgEncoder adds a 4 byte header that describes
          the length of the serialized message.  This decoder function
          assumes that the caller has stripped off that header.
          For example, Wallaroo assumes that the Pony TCP actor has
          already removed the header bytes as part of the
          ExternalChannelConnectNotifier's operation.
    """
    match _decode(data)?
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
    | (_StartGilesSenders(), let s: String) =>
      ExternalStartGilesSendersMsg
    | (_GilesSendersStarted(), let s: String) =>
      ExternalGilesSendersStartedMsg
    | (_Print(), let s: String) =>
      ExternalPrintMsg(s)
    | (_RotateLog(), let s: String) =>
      ExternalRotateLogFilesMsg(s)
    | (_CleanShutdown(), let s: String) =>
      ExternalCleanShutdownMsg(s)
    | (_Shrink(), let query: Bool,
      let node_names: Array[String] val, let num_nodes: U64) =>
      ExternalShrinkMsg(query, node_names, num_nodes)
    else
      error
    end

  fun _decode(data: Array[U8] val):
    ((U16, String) | (U16, Bool, Array[String] val, U64)) ?
  =>
    let rb = Reader
    rb.append(data)
    let type_tag = rb.u8()? // serialization type tag

    match type_tag
    | 1 =>
      let id = rb.u16_be()?
      let s_len: USize = USize.from[U32](rb.u32_be()?)
      let s = String.from_array(rb.block(s_len)?)
      (id, s)
    | 2 =>
      let id = rb.u16_be()?
      let query: Bool = if (rb.u8()? == 1) then true else false end
      let node_names = recover trn Array[String] end
      let node_names_size = USize.from[U32](rb.u32_be()?)

      // node_names.reserve(node_names_size)
      for i in Range[USize](0, node_names_size) do
        let size = USize.from[U32](rb.u32_be()?)
        let n = String.from_array(rb.block(size)?)
        node_names.push(n)
      end
      let num_nodes = U64.from[U32](rb.u32_be()?)

      (id, query, consume node_names, num_nodes)
    else
      error
    end

trait val ExternalMsg
  fun the_string() => String

class val ExternalDataMsg is ExternalMsg
  let data: String

  new val create(d: String) =>
    data = d

class val ExternalReadyMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

class val ExternalTopologyReadyMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

primitive ExternalStartMsg is ExternalMsg

class val ExternalShutdownMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

class val ExternalDoneShutdownMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

class val ExternalDoneMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

primitive ExternalStartGilesSendersMsg is ExternalMsg
primitive ExternalGilesSendersStartedMsg is ExternalMsg

class val ExternalPrintMsg is ExternalMsg
  let message: String

  new val create(m: String) =>
    message = m

class val ExternalRotateLogFilesMsg is ExternalMsg
  let node_name: String

  new val create(n: String) =>
    node_name = n

  fun the_string() => node_name

class val ExternalCleanShutdownMsg is ExternalMsg
  let msg: String

  new val create(m: String) =>
    msg = m

class val ExternalShrinkMsg is ExternalMsg
  let query: Bool
  let node_names: Array[String] val
  let num_nodes: U64
  var _header: Bool = true

  new val create(query': Bool,
    node_names': Array[String] val, num_nodes': U64) =>
    query = query'
    node_names = node_names'
    num_nodes = num_nodes'

  fun string(): String =>
    let nodes = Array[String]
    for n in node_names.values() do
      nodes.push(n)
    end
    var nodes_string = "|"
    for n in nodes.values() do
      nodes_string = nodes_string + "," + n
    end
    nodes_string = nodes_string + "|"
    "Query: " + query.string() + ", Node count: " + num_nodes.string() +
      ", Nodes: " + nodes_string

