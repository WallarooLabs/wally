/*

Copyright (C) 2016-2017, Wallaroo Labs
Copyright (C) 2016-2017, The Pony Developers
Copyright (c) 2014-2015, Causality Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/


use "collections"
use "promises"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/messages"
use "wallaroo/core/network"
use "wallaroo_labs/mort"

class val StreamTuple
  let id: StreamId
  let name: String
  let last_acked: PointOfReference

  new val create(stream_id: StreamId, stream_name: String,
    point_of_ref: PointOfReference)
  =>
    name = stream_name
    id = stream_id
    last_acked = point_of_ref

class GlobalConnectorStreamRegistry[In]
  var _worker_name: String
  let _source_name: String
  let _connections: Connections
  let _source_addr: (String, String)
  var _is_leader: Bool = false
  var _leader_name: String = "Initializer"
  var _active_stream_map: Map[StreamId, WorkerName] = _active_stream_map.create()
  var _inactive_stream_map: Map[StreamId, StreamTuple] =  _inactive_stream_map.create()
  var _source_addr_map: Map[WorkerName, (String, String)] =
    _source_addr_map.create()
  let _workers_set: Set[WorkerName] = _workers_set.create()
  let _pending_notify_promises:
    Map[ConnectorStreamNotifyId, (Promise[NotifyResult], ConnectorSource[In])] =
      _pending_notify_promises.create()
  let _pending_relinquish_promises:
    Map[ConnectorStreamRelinquishId, Promise[Bool]] =
      _pending_relinquish_promises.create()

  let _local_registry: LocalConnectorStreamRegsitry[In]

  new create(worker_name: WorkerName, source_name: String,
    connections: Connections, host: String, service: String,
    workers_list: Array[WorkerName] val,
    local_registry: LocalConnectorStreamRegistry[In])
  =>
    _local_registry = local_registry
    _worker_name = worker_name
    _source_name = source_name
    _connections = connections
    _source_addr = (host, service)
    for worker in workers_list.values() do
      _workers_set.set(worker)
    end
    _elect_leader()

  fun ref process_stream_relinquish(worker_name: WorkerName,
    stream_id: StreamId, last_acked_msg: PointOfReference,
    request_id: ConnectorStreamRelinquishId)
  =>
    if _is_leader then
      var relinquished = false
      try
        _active_stream_map.remove(stream_id)?
        _inactive_stream_map(stream_id) = last_acked_msg
        relinquished = true
      end
      _connections.respond_to_relinquish_stream_id_request(worker_name,
        _source_name, request_id, relinquished)
    else
      // TODO [source-migration-3]: should the message be forwarded to the
      // leader if we're not the leader?
      None
    end

  fun ref update_leader(new_leader_name: WorkerName) =>
    if not _is_leader then
      _leader_name = new_leader_name
    else
      // TODO [source-migration-3]: is there a scenario where this can
      // happen?
      None
    end

  fun ref relinquish_leadership(new_leader_name: WorkerName) =>
    if _is_leader then
      _initiate_leadership_relinquishment(new_leader_name)
    else
      // TODO [source-migration-3]: should the message be forwarded to the
      // leader if we're not the leader?
      None
    end

  fun ref process_relinquish_leadership_request(worker_name: WorkerName,
    active_stream_map: Map[StreamId, WorkerName] val,
    inactive_stream_map: Map[StreamId, StreamTuple] val,
    source_addr_map: Map[WorkerName, (String, String)] val)
  =>
    _accept_leadership_state(worker_name, active_stream_map,
      inactive_stream_map, source_addr_map)

  fun ref _accept_leadership_state(worker_name: WorkerName,
    active_stream_map: Map[StreamId, WorkerName] val,
    inactive_stream_map: Map[StreamId, StreamTuple] val,
    source_addr_map: Map[WorkerName, (String, String)] val)
  =>
    // update active stream map
    let active_stream_map_copy = Map[StreamId, WorkerName]()
    for (k,v) in active_stream_map.pairs() do
      active_stream_map_copy(k) = v
    end
    _active_stream_map = active_stream_map_copy

    // update inactive stream map
    let inactive_stream_map_copy = Map[StreamId, StreamTuple]()
    for (k,v) in inactive_stream_map.pairs() do
      inactive_stream_map_copy(k) = v
    end
    _inactive_stream_map = inactive_stream_map_copy

    // update source_addr_map
    let source_addr_map_copy = Map[WorkerName, (String, String)]()
    for (k,v) in source_addr_map.pairs() do
      source_addr_map_copy(k) = v
    end
    _source_addr_map = source_addr_map_copy

    // update leader state
    _is_leader = true
    _leader_name = _worker_name
    // send ack
    _send_leader_state_received_ack(worker_name)
    _broadcast_new_leader()


  fun ref add_source_address(worker_name: WorkerName, host: String,
    service: String)
  =>
    if _is_leader then
      _source_addr_map(worker_name) = (host, service)
      // TODO [source-migration-3]: we aren't acking here, primarily due
      // to the fact that it's most likely that the source_addr_map is no
      // longer needed
    else
      // TODO [source-migration-3]: should the message be forwarded to the
      // leader if we're not the leader?
      None
    end

  fun ref add_worker(worker_name: WorkerName) =>
    // TODO [source-migration-3]: we are lazily not re-electing leader on grow,
    // should we?
    _workers_set.set(worker_name)

  fun ref remove_worker(worker_name: WorkerName) =>
    // TODO [source-migration-3]: it is assumed that if the registry belongs
    // to the leaving worker, that streams would be relinquished in a different
    // step in the migration process
      _workers_set.unset(worker_name)
    if _is_leader and (worker_name == _worker_name) then
      try
        let new_leader_name = _leader_from_workers_list()?
        relinquish_leadership(new_leader_name)
      else
        // TODO [source-migration-3]: what should happen to leader state, if a
       // leader cannot be retrieved from the workers list?
        None
      end
    end

  ////////////////
  // STREAM_NOTIFY
  ////////////////
  fun ref stream_notify(session_tag: USize, request_id: ConnectorStreamNotifyId,
    stream_id: StreamId, stream_name: String, point_of_ref: PointOfReference,
    promise: Promise[NotifyResult], connector_source: ConectorSource[In] tag)
  =>
    """
    local->global stream_notify
    """
    if _is_leader then
      // check active first
      if _active_stream_map.contains(stream_id) then
        // stream is already claimed by a source on another worker
        // reject stream notify
        _local_registry.stream_notify_global_result(session_tag, false,
          stream_id, stream_name, 0,
          promise, connector_source)
      else
        try
          // stream_id is known and inactive
          let stream = _inactive_stream_map.remove(stream_id)?
          Invariant((stream_id == stream.id) and (stream_name == stream.name))
          // mark it as claimed by self in _active_stream_map
          _active_stream_map(stream_id) = _worker_name
          // accept stream notify
          _local_registry.stream_notify_global_result(session_tag, true,
            stream.id, stream.name, stream.last_acked,
            promise, connector_source)
        else
          // new stream
          // set self as owner
          _active_stream_map(stream_id) = _worker_name
          // accept stream notify
          _local_registry.stream_notify_global_result(session_tag, true,
            stream_id, stream_name, point_of_ref,
            promise, connector_source)
        end
      end
    else
      // Not leader, go over conections to leader worker
      _pending_notify_promises(request_id) = (promise, connector_source)
      _connections.stream_notify(_leader_name, _worker_name,
        _source_name, stream_id, stream_name, point_of_ref, request_id)
    end

  fun ref process_stream_notify_msg(worker_name: String, stream_id: StreamId,
    stream_name: String, point_of_ref: PointOfReference,
    request_id: ConnectorStreamNotifyId)
  =>
    """
    worker->leader stream_notify
    """
    if _is_leader then
      // check active
      if _active_stream_map.contains(stream_id) then
        // reject
        return _connections.respond_to_stream_notify(worker_name, _source_name,
          false, stream_id, stream_name, point_of_ref, request_id)
      else
        // accept, but check inactive for up to date info
        let success = true
        let stream = try
          // known inactive stream
          _inactive_streams_map.remove(stream_id)?
        else
          // new stream
          StreamTuple(stream_id, steam_name, point_of_ref)
        end
        // update _active_stream_map
        _active_stream_map.update(stream_id, worker_name)
        // send response to requesting worker
        return _connections.respond_to_stream_notify(worker_name, _source_name,
          success, stream.id, stream.name, stream.last_acked, request_id)
      end
    else
      // TODO [source-migration]: should the message be forwarded to the
      // leader if we're not the leader?
      // [NH] maybe respond with error msg?
      //      This does indicate that the sending worker has the wrong leader
      //      info, which is a consistency violation... that should cause the
      //      sending worker to fail (but not necessarily the receiving. For
      //      example if the sending worker did not belong in the cluster why
      //      should we fail the receiver?)
      ifdef debug then
        @printf[I32](("GlobalConnectorStreamRegistry is not leader but "
          + "received a stream_notify message. Ignoring.\n").cstring())
      end
    end

  fun ref process_stream_notify_response_msg(request_id: ConnectorStreamNotifyId,
    success: Bool, stream_id: StreamId, stream_name: String,
    point_of_ref: PointOfReference)
  =>
    """
    leader->worker stream_notify_result
    """
    try
      (let promise, let source) = _pending_notify_promises.remove(request_id)?
      _local_registry.stream_notify_global_result(session_tag, success,
        stream_id, stream_name, point_of_ref,
        promise, source)
    else
      ifdef debug then
        @printf[I32](("GlobalConnectorStreamRegistry received a stream_ "
          + "notify reponse message for an unknown request."
          +" Ignoring.\n").cstring())
      end
    end

  ////////////////////
  // STREAM RELINQUISH
  ////////////////////
  fun ref process_stream_relinquish_msg(msg: ConnectorStreamRelinquishMsg) =>
    """
    Process a stream relinquish message from another worker
    """
    // TODO [source-migration] implement this
    None


  fun ref stream_relinquish(stream_id: StreamId,
    last_acked_msg: PointOfReference,
    request_id: ConnectorStreamRelinquishId, promise: Promise[Bool])
  =>
    if _is_leader then
      try
        _active_stream_map.remove(stream_id)?
        _inactive_stream_map(stream_id) = last_acked_msg
        promise(true)
      else
        // Do we ack ok to remove locally if not present in global map?
        None
      end
    else
      _pending_relinquish_promises(request_id) = promise
      _connections.relinquish_stream_id(_leader_name, _worker_name,
        _source_name, stream_id, last_acked_msg, request_id)
    end

  fun ref contains_notify_request(request_id: ConnectorStreamNotifyId): Bool =>
    _pending_notify_promises.contains(request_id)

  fun ref contains_relinquish_request(
    request_id: ConnectorStreamRelinquishId): Bool
  =>
    _pending_relinquish_promises.contains(request_id)

  fun ref process_stream_relinquish_response(
    request_id: ConnectorStreamRelinquishId,
    relinquish: Bool)
  =>
    try
      let promise = _pending_relinquish_promises(request_id)?
      promise(relinquish)
    end

  fun ref complete_leader_state_relinquish(new_leader_name: WorkerName) =>
    _relinquish_leader_state(new_leader_name)

  fun ref _relinquish_leader_state(new_leader_name: WorkerName) =>
    _active_stream_map = Map[StreamId, WorkerName]()
    _inactive_stream_map = Map[StreamId, StreamTuple]()
    _source_addr_map = Map[WorkerName, (String, String)]()
    _is_leader = false
    _leader_name = new_leader_name

  fun ref _elect_leader() =>
    try
      let leader_name = _leader_from_workers_list()?
      if (leader_name == _worker_name) then
        _initiate_leader_state()
      else
        _leader_name = leader_name
        _send_leader_source_address()
      end
    else
      // unable to elect a leader
      Fail()
    end

  fun ref _leader_from_workers_list(): WorkerName ? =>
    let workers_list = Array[WorkerName]
    for worker in _workers_set.values() do
      workers_list.push(worker)
    end
    let sorted_worker_names =
      Sort[Array[WorkerName], WorkerName](workers_list)
    sorted_worker_names(0)?

  fun ref _initiate_leader_state() =>
    _is_leader = true
    _leader_name = _worker_name
    _active_stream_map = Map[StreamId, WorkerName]()
    _inactive_stream_map = Map[StreamId, StreamTuple]()
    _source_addr_map = Map[WorkerName, (String, String)]()
    _source_addr_map(_worker_name) = (_source_addr._1, _source_addr._2)

  fun ref _send_leader_source_address() =>
    try
      let leader_name = _leader_from_workers_list()?
      _connections.add_connector_stream_source_addr(leader_name, _worker_name,
        _source_name, _source_addr._1, _source_addr._2)
    else
      // Could not retrieve a leader
      Fail()
    end

  fun ref _send_leader_state_received_ack(worker_name: WorkerName) =>
    _connections.connector_reg_leader_state_received_ack(_leader_name, worker_name, _source_name)

  fun ref _broadcast_new_leader() =>
    let workers_list_size = _workers_set.size()
    let workers_list = recover trn Array[WorkerName](workers_list_size) end
    for worker in _workers_set.values() do
      workers_list.push(worker)
    end

    _connections.connector_stream_reg_broadcast_new_leader(
      _worker_name, _source_name, consume workers_list)

  fun ref _initiate_leadership_relinquishment(new_leader_name: WorkerName) =>
    let active_stream_map_copy = recover trn Map[StreamId, WorkerName] end
    for (k,v) in _active_stream_map.pairs() do
      active_stream_map_copy(k) = v
    end
    let inactive_stream_map_copy = recover trn Map[StreamId, StreamTuple] end
    for (k,v) in _inactive_stream_map.pairs() do
      inactive_stream_map_copy(k) = v
    end
    let source_addr_map_copy = recover trn
      Map[WorkerName, (String, String)]
    end
    for (k,v) in _source_addr_map.pairs() do
      source_addr_map_copy(k) = v
    end

    _connections.connector_stream_relinquish_leadership_state(
      new_leader_name, _worker_name, _source_name,
      consume active_stream_map_copy, consume inactive_stream_map_copy,
      consume source_addr_map_copy)


class ActiveStreamTuple
  let id: StreamId
  let name: String
  var source: (Connectorsource[In] | None)
  var last_acked: PointOfReference
  var last_seen: PointOfReference

  new create(stream_id': StreamId, stream_name': String,
    last_acked': PointOfReference, last_seen': PointOfReference,
    source': (ConnectorSource[In] | None))
  =>
    id = stream_id'
    name = stream_name'
    source = source'
    last_acked = last_acked'
    last_seen = last_seen'

class LocalConnectorStreamRegistry[In: Any val]
   // Global Stream Registry
  let _global_registry: GlobalConnectorStreamRegistry[In]

  // Local stream registry
  // (stream_name, connector_source, last_acked_por, last_seen_por)
  let active_streams: Map[StreamId, ActiveStreamTuple] = active_streams.create()

  new create(worker_name: WorkerName, source_name: String,
    connections: Connections, host: String, service: String,
    workers_list: Array[WorkerName] val)
  =>
    _global_registry = _global_registry.create(_worker_name,
      _pipeline_name, _connections, _host, _service, workers_list, this)

  ///////////////////
  // MESSAGE HANDLING
  ///////////////////

  fun ref listener_msg_received(msg: SourceListenerMsg) =>
    // we only care for messages that belong to this source name
    if (msg.source_name() == _pipeline_name) then
      match msg
      |  let m: ConnectorStreamNotifyMsg =>
        _global_registry.process_stream_notify_msg(m)

      | let m: ConnectorStreamNotifyResponseMsg =>
        _global_registry.process_stream_notify_response_msg(m)

      | let m: ConnectorStreamRelinquishMsg =>
        _global_registry.process_stream_relinquish_msg(m)

      | let m: ConnectorStreamRelinquishResponseMsg =>
        _global_registry.process_stream_relinquish_msg(m)

      | let m: ConnectorLeadershipRelinquishMsg =>
        _global_registry.process_leadership_relinquish_msg(m)

      | let m: ConnectorAddSourceAddrMsg =>
        _global_registry.process_add_source_addr_msg(m)

      | let m: ConnectorNewLeaderMsg =>
        _global_registry.process_new_leader_msg(m)

      | let m: ConnectorLeaderStateReceivedAckMsg =>
        _global_registry.process_leader_state_received_msg(m)

      end
    else
      @printf[I32](("**Dropping message** _pipeline_name: " +
         _pipeline_name +  " =/= source_name: " + msg.source_name() + " \n")
        .cstring())
    end

  /////////
  // GLOBAL
  /////////
  fun ref add_worker(worker: WorkerName) =>
    _global_registry.add_worker(worker)

  fun ref remove_worker(worker: WorkerName) =>
    _global_registry.remove_worker(worker)

  /////////////
  // LOCAL
  /////////////

  fun ref stream_is_present(stream_id: StreamId): Bool =>
    active_streams.contains(stream_id)

  fun ref stream_notify(session_tag: USize, request_id: ConnectorStreamNotify,
    stream_id: StreamId, stream_name: String,
    promise: Promise[NotifyResult], connector_source: ConectorSource[In] tag)
  =>
    // stream_id in active_streams.contains()?
    try
      let stream = active_streams(stream_id)?
      // connector_source == active_streams(stream_id).connector_source?
      if stream.source == connector_source then
        // accept: already owned by requesting source
        // Use last_seen as resume_from point
        stream_notify_local_result(session_tag, true, stream_id,
          stream.stream_name, stream.last_seen, promise, connector_source)
      else
        // reject: owned by another source in this registry
        // use last_acked as resume_from point
        // Note: this allows connectors to get info on streams owned by other
        // connectors, and even keep tabs on their progress.
        // Maybe this is exposing too much information... or maybe this could
        // be useful, for example with a hot-standby connector
        stream_notify_local_result(session_tag, false, stream_id,
          stream.stream_name, stream.last_acked, promise, connector_source)
      end
    else
      // defer to global
      global_registry.stream_notify(session_tag, request_id,
        stream_id, stream_name, promise, connector_source)
    end

  fun ref stream_notify_local_result(session_tag: USize, success: Bool,
    stream_id: StreamId, stream_name: String, resume_from: PointOfReference,
    promise: Promise[NotifyResult], connector_source: ConnectorSource[In] tag)
  =>
    // No local state to update.
    promise(NotifyResult(connector_source, session_tag, success, resume_from))

  fun ref stream_notify_global_result(session_tag: USize, success: Bool,
    stream_id: StreamId, stream_name: String, resume_from: PointOfReference,
    promise: Promise[NotifyResult], connector_source: ConnectorSource[In] tag)
  =>
    if success then
      // update locally
      active_streams(stream_id) = ActiveStreamTuple(stream_id, stream_name,
        resume_from, resume_from, connector_source)
    end
    promise(NotifyResult(connector_source, session_tag, success, resume_from))

  fun ref stream_update(stream_id: StreamId, checkpoint_id: CheckpointId,
    last_acked_por: PointOfReference, last_seen_por: PointOfReference,
    connector_source: (ConnectorSource[In] tag | None))
  =>
    let update = if connector_source is None then
      true
    else
      try
        if active_streams(stream_id)?._2 is None then
          false
        else
          true
        end
      else
        false
      end
    end

    ifdef "trace" then
      @printf[I32]("TRACE: %s.%s(stmid %lu, chkp %lu, p-o-r %lu, l-msgid %lu, conn %s) update %s\n".cstring(),
        __loc.type_name().cstring(), __loc.method_name().cstring(),
        stream_id, checkpoint_id, point_of_reference, last_message_id,
        (if connector_source is None then
          "None"
        else
          "not None"
        end).cstring(), update.string().cstring())
    end

    if update then
      let stream_name = try active_streams(stream_id)?._1 else Fail(); "" end
      active_streams(stream_id) =
        (stream_name, connector_source, last_acked_por, last_seen_por)
    end


  fun ref stream_relinquish(stream_id: StreamId, last_acked: PointOfReference) =>
    None

class val ConnectorStreamNotifyId is Equatable[ConnectorStreamNotifyId]
  let stream_id: StreamId
  let session_id: RoutingId

  new val create(stream_id': StreamId, session_id': RoutingId) =>
    stream_id = stream_id'
    session_id = session_id'

  fun eq(that: ConnectorStreamNotifyId box): Bool =>
     """
    Returns true if the request is for the same session and stream.
    """
    (session_id == that.session_id) and (stream_id == that.stream_id)

  fun hash(): USize =>
    session_id.hash() xor stream_id.hash()


class val ConnectorStreamRelinquishId is
    Equatable[ConnectorStreamRelinquishId]
  let stream_id: StreamId
  let session_id: RoutingId

  new val create(stream_id': StreamId, session_id': RoutingId) =>
    stream_id = stream_id'
    session_id = session_id'


  fun eq(that: ConnectorStreamRelinquishId box): Bool =>
     """
    Returns true if the request is for the same session and stream.
    """
    (session_id == that.session_id) and (stream_id == that.stream_id)

  fun hash(): USize =>
    session_id.hash() xor stream_id.hash()
