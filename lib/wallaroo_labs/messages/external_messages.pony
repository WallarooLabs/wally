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
use "../string_set"
use "../../wallaroo/core/common"
use "../../wallaroo/core/topology"
use "../../wallaroo_labs/mort"

primitive _Print                                    fun apply(): U16 => 1
primitive _RotateLog                                fun apply(): U16 => 2
primitive _CleanShutdown                            fun apply(): U16 => 3
primitive _ShrinkRequest                            fun apply(): U16 => 4
primitive _ShrinkQueryResponse                      fun apply(): U16 => 5
primitive _ShrinkErrorResponse                      fun apply(): U16 => 6
primitive _PartitionQuery                           fun apply(): U16 => 7
primitive _PartitionQueryResponse                   fun apply(): U16 => 8
primitive _ClusterStatusQuery                       fun apply(): U16 => 9
primitive _ClusterStatusQueryResponse               fun apply(): U16 => 10
primitive _ClusterStatusQueryResponseNotInitialized fun apply(): U16 => 11
primitive _PartitionCountQuery                      fun apply(): U16 => 12
primitive _PartitionCountQueryResponse              fun apply(): U16 => 13
primitive _SourceIdsQuery                           fun apply(): U16 => 14
primitive _SourceIdsQueryResponse                   fun apply(): U16 => 15
primitive _ReportStatus                             fun apply(): U16 => 16
primitive _StateEntityQuery                         fun apply(): U16 => 17
primitive _StateEntityQueryResponse                 fun apply(): U16 => 18
primitive _StatelessPartitionQuery                  fun apply(): U16 => 19
primitive _StatelessPartitionQueryResponse          fun apply(): U16 => 20
primitive _StateEntityCountQuery                    fun apply(): U16 => 21
primitive _StateEntityCountQueryResponse            fun apply(): U16 => 22
primitive _StatelessPartitionCountQuery             fun apply(): U16 => 23
primitive _StatelessPartitionCountQueryResponse     fun apply(): U16 => 24

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
    """
    A message requesting the current distribution of partition steps across
    workers (organized by partition type and partition name).
    """
    _encode(_PartitionQuery(), "", wb)

  fun partition_query_response(
    state_routers: Map[U128, StatePartitionRouter],
    stateless_routers: Map[U128, StatelessPartitionRouter],
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let digest_map = _partition_digest(state_routers, stateless_routers)
    let pqr = PartitionQueryStateAndStatelessIdsEncoder(digest_map)
    _encode(_PartitionQueryResponse(), pqr, wb)

  fun cluster_status_query(wb: Writer = Writer): Array[ByteSeq] val =>
    """
    A message requesting current cluster status. How many workers? What are
    the worker names? Is the cluster currently processing messages (i.e. not
    in a stop the world phase)?
    """
    _encode(_ClusterStatusQuery(), "", wb)

  fun cluster_status_query_reponse_not_initialized(wb: Writer = Writer):
    Array[ByteSeq] val
  =>
    _encode(_ClusterStatusQueryResponseNotInitialized(), "", wb)

  fun cluster_status_query_response(worker_count: USize,
    worker_names: Array[String] val, stop_the_world_in_process: Bool,
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let csr = ClusterStatusQueryJsonEncoder.response(worker_count.u64(),
      worker_names, stop_the_world_in_process)
    _encode(_ClusterStatusQueryResponse(), csr, wb)

  fun partition_count_query(wb: Writer = Writer): Array[ByteSeq] val =>
    """
    A message requesting the current count of partition steps across
    workers (organized by partition type and partition name).
    """
    _encode(_PartitionCountQuery(), "", wb)

  fun partition_count_query_response(
    state_routers: Map[U128, StatePartitionRouter],
    stateless_routers: Map[U128, StatelessPartitionRouter],
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let digest_map = _partition_digest(state_routers, stateless_routers)
    let pqr = PartitionQueryStateAndStatelessCountsEncoder(digest_map)
    _encode(_PartitionCountQueryResponse(), pqr, wb)

  fun source_ids_query(wb: Writer = Writer): Array[ByteSeq] val =>
    """
    A message requesting the ids of all sources in the cluster
    """
    _encode(_SourceIdsQuery(), "", wb)

  fun source_ids_query_response(source_ids: Array[String] val,
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let sis = SourceIdsQueryEncoder.response(source_ids)
    _encode(_SourceIdsQueryResponse(), sis, wb)

  fun state_entity_query(wb: Writer = Writer): Array[ByteSeq] val =>
    """
    A message requesting the state entities on the worker (organized by entity
    key).
    """
    _encode(_StateEntityQuery(), "", wb)

  fun state_entity_query_response(
    local_keys: Map[RoutingId, StringSet],
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let digest_map = _state_entity_digest(local_keys)
    let seqr = StateEntityQueryEncoder.state_entity_keys(digest_map)
    @printf[I32]("!@ HERE'S THE StateEntityResponse: %s\n".cstring(), seqr.cstring())
    _encode(_StateEntityQueryResponse(), seqr, wb)

  fun stateless_partition_query(wb: Writer = Writer): Array[ByteSeq] val =>
    """
    A message requesting the current distribution of stateless partition across
    workers (organized by entity key).
    """
    _encode(_StatelessPartitionQuery(), "", wb)

  fun stateless_partition_query_response(
    stateless_routers: Map[U128, StatelessPartitionRouter],
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let digest_map = _stateless_partition_digest(stateless_routers)
    let spqr = StatelessPartitionQueryEncoder.stateless_partition_keys(digest_map)
    _encode(_StatelessPartitionQueryResponse(), spqr, wb)

  fun state_entity_count_query(wb: Writer = Writer): Array[ByteSeq] val =>
    """
    A message requesting the count of state entities on the worker (organized by
    entity key).
    """
    _encode(_StateEntityCountQuery(), "", wb)

  fun state_entity_count_query_response(
    local_keys: Map[U128, StringSet],
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let digest_map = _state_entity_digest(local_keys)
    let secqr = StateEntityCountQueryEncoder.state_entity_count(digest_map)
    _encode(_StateEntityCountQueryResponse(), secqr, wb)

  fun stateless_partition_count_query(wb: Writer = Writer): Array[ByteSeq] val =>
    """
    A message requesting the count of stateless partition across workers
    (organized by entity key).
    """
    _encode(_StatelessPartitionCountQuery(), "", wb)

  fun stateless_partition_count_query_response(
    stateless_routers: Map[U128, StatelessPartitionRouter],
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let digest_map = _stateless_partition_digest(stateless_routers)
    let spcqr =
      StatelessPartitionCountQueryEncoder.stateless_partition_count(digest_map)
    _encode(_StatelessPartitionCountQueryResponse(), spcqr, wb)

  fun _partition_digest(state_routers: Map[U128, StatePartitionRouter],
    stateless_routers: Map[U128, StatelessPartitionRouter]):
    Map[String, Map[String, Map[String, Array[String] val] val] val] val
  =>
    let state_ps =
      recover iso Map[String, Map[WorkerName, Array[String] val] val] end
    let stateless_ps =
      recover iso Map[String, Map[WorkerName, Array[String] val] val] end

    for (k, v) in state_routers.pairs() do
      state_ps(k.string()) = v.distribution_digest()
    end

    for (k, v) in stateless_routers.pairs() do
      stateless_ps(k.string()) = v.distribution_digest()
    end
    let digest_map =
      recover trn
        Map[String, Map[String, Map[WorkerName, Array[String] val] val] val]
      end
    digest_map("state_partitions") = consume state_ps
    digest_map("stateless_partitions") = consume stateless_ps
    consume digest_map

  fun _state_entity_digest(local_keys: Map[RoutingId, StringSet]):
    Map[String, Array[String] val] val
  =>
    let state_ps = recover trn Map[String, Array[Key] val] end

    for (step_group, keys) in local_keys.pairs() do
      let ks = recover iso Array[Key] end


      for k in keys.values() do
        //!@
        if ks.contains(k) then
          @printf[I32]("!@ Already have %s!\n".cstring(), k.cstring())
          Fail()
        end

        ks.push(k)
      end

      state_ps(step_group.string()) = consume ks
    end

    consume state_ps

  fun _stateless_partition_digest(
    stateless_routers: Map[U128, StatelessPartitionRouter]):
    Map[String, Map[String, Array[String] val] val] val
  =>
    let stateless_ps =
      recover iso Map[String, Map[String, Array[String] val] val] end

    for (k, v) in stateless_routers.pairs() do
      stateless_ps(k.string()) = v.distribution_digest()
    end
    stateless_ps

  fun report_status(code: String, wb: Writer = Writer): Array[ByteSeq] val =>
    _encode(_ReportStatus(), code, wb)

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
    | (_ClusterStatusQuery(), let s: String) =>
      ExternalClusterStatusQueryMsg
    | (_ClusterStatusQueryResponse(), let s: String) =>
      ClusterStatusQueryJsonDecoder.response(s)?
    | (_ClusterStatusQueryResponseNotInitialized(), let s: String) =>
      ExternalClusterStatusQueryResponseNotInitializedMsg
    | (_PartitionCountQuery(), let s: String) =>
      ExternalPartitionCountQueryMsg
    | (_PartitionCountQueryResponse(), let s: String) =>
      ExternalPartitionCountQueryResponseMsg(s)
    | (_SourceIdsQuery(), let s: String) =>
      ExternalSourceIdsQueryMsg
    | (_SourceIdsQueryResponse(), let s: String) =>
      SourceIdsQueryJsonDecoder.response(s)?
    | (_ReportStatus(), let s: String) =>
      ExternalReportStatusMsg(s)
    | (_StateEntityQuery(), let s: String) =>
      ExternalStateEntityQueryMsg
    | (_StateEntityQueryResponse(), let s: String) =>
      ExternalStateEntityQueryResponseMsg(s)
    | (_StatelessPartitionQuery(), let s: String) =>
      ExternalStatelessPartitionQueryMsg
    | (_StatelessPartitionQueryResponse(), let s: String) =>
      ExternalStatelessPartitionQueryResponseMsg(s)

    | (_StateEntityCountQuery(), let s: String) =>
      ExternalStateEntityCountQueryMsg
    | (_StateEntityCountQueryResponse(), let s: String) =>
      ExternalStateEntityCountQueryResponseMsg(s)
    | (_StatelessPartitionCountQuery(), let s: String) =>
      ExternalStatelessPartitionCountQueryMsg
    | (_StatelessPartitionCountQueryResponse(), let s: String) =>
      ExternalStatelessPartitionCountQueryResponseMsg(s)
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

primitive ExternalClusterStatusQueryMsg is ExternalMsg

class val ExternalClusterStatusQueryResponseNotInitializedMsg is ExternalMsg
  let json: String = "{\"processing_messages\": false}"

  fun string(): String =>
    "Processing messages: false"

class val ExternalClusterStatusQueryResponseMsg is ExternalMsg
  let worker_count: U64
  let worker_names: Array[String] val
  let processing_messages: Bool
  let json: String

  new val create(worker_count': U64, worker_names': Array[String] val,
    processing_messages': Bool, json': String)
  =>
    worker_count = worker_count'
    worker_names = worker_names'
    processing_messages = processing_messages'
    json = json'

  fun string(): String =>
    let ws = Array[String]
    for w in worker_names.values() do
      ws.push(w)
    end
    var workers_string = "|"
    for w in ws.values() do
     workers_string = workers_string + w + ","
    end
    workers_string = workers_string + "|"
    "Processing messages: " + processing_messages.string() +
      ", Worker count: " + worker_count.string() + ", Workers: " +
      workers_string

primitive ExternalPartitionCountQueryMsg is ExternalMsg

class val ExternalPartitionCountQueryResponseMsg is ExternalMsg
  let msg: String

  new val create(m: String) =>
    msg = m

primitive ExternalSourceIdsQueryMsg is ExternalMsg

class val ExternalSourceIdsQueryResponseMsg is ExternalMsg
  let source_ids: Array[String] val
  let json: String

  new val create(source_ids': Array[String] val, json': String val) =>
    source_ids = source_ids'
    json = json'

class val ExternalReportStatusMsg is ExternalMsg
  let code: String

  new val create(c: String) =>
    code = c

primitive ExternalStateEntityQueryMsg is ExternalMsg

class val ExternalStateEntityQueryResponseMsg is ExternalMsg
  let msg: String

  new val create(m: String) =>
    msg = m

primitive ExternalStatelessPartitionQueryMsg is ExternalMsg

class val ExternalStatelessPartitionQueryResponseMsg is ExternalMsg
  let msg: String

  new val create(m: String) =>
    msg = m

primitive ExternalStateEntityCountQueryMsg is ExternalMsg

class val ExternalStateEntityCountQueryResponseMsg is ExternalMsg
  let msg: String

  new val create(m: String) =>
    msg = m

primitive ExternalStatelessPartitionCountQueryMsg is ExternalMsg

class val ExternalStatelessPartitionCountQueryResponseMsg is ExternalMsg
  let msg: String

  new val create(m: String) =>
    msg = m
