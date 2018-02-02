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
use "../query"
use "../../wallaroo/core/topology"

primitive _Print                                fun apply(): U16 => 1
primitive _RotateLog                            fun apply(): U16 => 2
primitive _CleanShutdown                        fun apply(): U16 => 3
primitive _ShrinkRequest                        fun apply(): U16 => 4
primitive _ShrinkQueryResponse                  fun apply(): U16 => 5
primitive _ShrinkErrorResponse                  fun apply(): U16 => 6
primitive _PartitionQuery                       fun apply(): U16 => 7
primitive _PartitionQueryResponse               fun apply(): U16 => 8


primitive ExternalMsgEncoder
  fun _encode(id: U16, s: String, wb: Writer): Array[ByteSeq] val =>
    let s_array = s.array()
    let size = s_array.size()
    wb.u32_be(2 + size.u32())
    wb.u16_be(id)
    wb.write(s_array)
    wb.done()

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

  fun shrink_request(query: Bool, node_names: Array[String] val =
    recover Array[String] end, num_nodes: U64 = 0, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_ShrinkRequest(), ShrinkQueryJsonEncoder.request(query, node_names,
      num_nodes), wb)

  fun shrink_query_response(node_names: Array[String] val =
    recover Array[String] end, num_nodes: U64 = 0, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_ShrinkQueryResponse(), ShrinkQueryJsonEncoder.response(node_names,
      num_nodes), wb)

  fun shrink_error_response(message: String, wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_ShrinkErrorResponse(), message, wb)

  fun partition_query(wb: Writer = Writer): Array[ByteSeq] val =>
    _encode(_PartitionQuery(), "", wb)

  fun partition_query_response(state_routers: Map[String, PartitionRouter],
    stateless_routers: Map[U128, StatelessPartitionRouter],
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let state_ps =
      recover iso Map[String, Map[String, Array[String] val] val] end
    let stateless_ps =
      recover iso Map[String, Map[String, Array[String] val] val] end

    for (k, v) in state_routers.pairs() do
      state_ps(k) = v.distribution_digest()
    end

    for (k, v) in stateless_routers.pairs() do
      stateless_ps(k.string()) = v.distribution_digest()
    end
    let digest_map =
      Map[String, Map[String, Map[String, Array[String] val] val] val]
    digest_map("state_partitions") = consume state_ps
    digest_map("stateless_partitions") = consume stateless_ps
    let pqr = PartitionQueryEncoder.state_and_stateless(digest_map)
    _encode(_PartitionQueryResponse(), pqr, wb)

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
    | (_Print(), let s: String) =>
      ExternalPrintMsg(s)
    | (_RotateLog(), let s: String) =>
      ExternalRotateLogFilesMsg(s)
    | (_CleanShutdown(), let s: String) =>
      ExternalCleanShutdownMsg(s)
    | (_ShrinkRequest(), let json: String) =>
      ShrinkQueryJsonDecoder.request(json)?
    | (_ShrinkQueryResponse(), let json: String) =>
      ShrinkQueryJsonDecoder.response(json)?
    | (_ShrinkErrorResponse(), let s: String) =>
      ExternalShrinkErrorResponseMsg(s)
    | (_PartitionQuery(), let s: String) =>
      ExternalPartitionQueryMsg
    | (_PartitionQueryResponse(), let s: String) =>
      ExternalPartitionQueryResponseMsg(s)
    else
      error
    end

  fun _decode(data: Array[U8] val): (U16, String) ? =>
    let s_len = data.size() - 2
    let rb = Reader
    rb.append(data)
    let id = rb.u16_be()?
    let s = String.from_array(rb.block(s_len)?)
    (id, s)

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

class val ExternalShrinkRequestMsg is ExternalMsg
  let query: Bool
  let node_names: Array[String] val
  let num_nodes: U64

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

class val ExternalShrinkQueryResponseMsg is ExternalMsg
  let node_names: Array[String] val
  let num_nodes: U64

  new val create(node_names': Array[String] val, num_nodes': U64) =>
    node_names = node_names'
    num_nodes = num_nodes'

  fun string(): String =>
    let nodes = Array[String]
    for n in node_names.values() do
      nodes.push(n)
    end
    var nodes_string = "|"
    for n in nodes.values() do
      nodes_string = nodes_string + n + ","
    end
    nodes_string = nodes_string + "|"
    "Node count: " + num_nodes.string() + ", Nodes: " + nodes_string

class val ExternalShrinkErrorResponseMsg is ExternalMsg
  let msg: String

  new val create(m: String) =>
    msg = m

primitive ExternalPartitionQueryMsg is ExternalMsg

class val ExternalPartitionQueryResponseMsg is ExternalMsg
  let msg: String

  new val create(m: String) =>
    msg = m
