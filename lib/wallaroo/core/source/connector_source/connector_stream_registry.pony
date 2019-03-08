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
  let stream_name: String
  let stream_id: U64
  let last_acked: U64

  new val create(name: String, id: U64, point_of_reference: U64) =>
    stream_name = name
    stream_id = id
    last_acked = point_of_reference

class GlobalConnectorStreamRegistry
  var _worker_name: String
  let _source_name: String
  let _connections: Connections
  let _source_addr: (String, String)
  var _is_leader: Bool = false
  var _leader_name: String = "Initializer"
  var _active_stream_map: Map[U64, WorkerName] = _active_stream_map.create()
  var _inactive_stream_map: Map[U64, StreamTuple] =  _inactive_stream_map.create()
  var _source_addr_map: Map[WorkerName, (String, String)] =
    _source_addr_map.create()
  let _workers_set: Set[WorkerName] = _workers_set.create()
  let _pending_notify_promises:
    Map[ConnectorStreamNotify, Promise[Bool]] =
      _pending_notify_promises.create()
  let _pending_relinquish_promises:
    Map[ConnectorStreamRelinquish, Promise[Bool]] =
      _pending_relinquish_promises.create()

  new create(worker_name: WorkerName, source_name: String,
    connections: Connections, host: String, service: String,
    workers_list: Array[WorkerName] val)
  =>
    _worker_name = worker_name
    _source_name = source_name
    _connections = connections
    _source_addr = (host, service)
    for worker in workers_list.values() do
      _workers_set.set(worker)
    end
    _elect_leader()

  fun ref process_stream_notify(worker_name: String, stream_id: U64,
    request_id: ConnectorStreamNotify)
  =>
    if _is_leader then
      (let can_use: Bool, last_por: U64) = try
        // stream is known and inactive (allow)
        (true, _inactive_stream_map.remove(stream_id)?._2)
      else
        if _active_stream_map.contains(stream_id) then
          // stream is known and active (deny)
          (false, 0)
        else
          // stream is new (allow)
          (true, 0)
        end
      end
      // send response to requesting worker
      _connections.respond_to_stream_id_request(worker_name, _source_name,
        stream_id, point_of_reference, request_id, can_use)
      if can_use then
        _active_stream_map.update(stream_id, worker_name)
      end
    else
      // TODO [source-migration]: should the message be forwarded to the
      // leader if we're not the leader?
      // TODO [source-migration]: log a message, possibly only in debug mode
      None
    end

  fun ref process_stream_relinquish(worker_name: WorkerName,
    stream_id: U64, last_acked_msg: U64,
    request_id: ConnectorStreamRelinquish)
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
    active_stream_map: Map[U64, WorkerName] val,
    inactive_stream_map: Map[U64, U64] val,
    source_addr_map: Map[WorkerName, (String, String)] val)
  =>
    _accept_leadership_state(worker_name, active_stream_map,
      inactive_stream_map, source_addr_map)

  fun ref _accept_leadership_state(worker_name: WorkerName,
    active_stream_map: Map[U64, WorkerName] val,
    inactive_stream_map: Map[U64, U64] val,
    source_addr_map: Map[WorkerName, (String, String)] val)
  =>
    // update active stream map
    let active_stream_map_copy = Map[U64, WorkerName]()
    for (k,v) in active_stream_map.pairs() do
      active_stream_map_copy(k) = v
    end
    _active_stream_map = active_stream_map_copy

    // update inactive stream map
    let inactive_stream_map_copy = Map[U64, U64]()
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

  fun ref stream_notify(session_tag: USize, stream_id: U64,
    request_id: ConnectorStreamNotify, promise: Promise[Bool])
  =>
    _stream_notify(session_tag, stream_id, request_id, promise)

  // TODO [source-migration][nisan]: Continue from here. add session tag.
  fun ref _stream_notify(session_tag: USize, stream_id: U64,
    request_id: ConnectorStreamNotify, promise: Promise[Bool])
  =>
    if _is_leader then
      try
        // stream_id is known and unclaimed
        let last_ack = _inactive_stream_map.remove(stream_id)?
        // mark it as claimed by self in _active_stream_map
        _active_stream_map(stream_id) = _worker_name
        // respond to local registry immediately
        
      let can_use = not _active_stream_map.contains(stream_id)
      if can_use then
        _active_stream_map.update(stream_id, _worker_name)
      end
      promise(can_use)
    else
      _pending_notify_promises(request_id) = promise
      _connections.request_stream_id(_leader_name, _worker_name,
        _source_name, stream_id, request_id)
    end

  fun ref stream_relinquish(stream_id: U64, last_acked_msg: U64,
    request_id: ConnectorStreamRelinquish, promise: Promise[Bool])
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

  fun ref contains_request(request_id: ConnectorStreamNotify): Bool =>
    _pending_notify_promises.contains(request_id)

  fun ref contains_relinquish_request(
    request_id: ConnectorStreamRelinquish): Bool
  =>
    _pending_relinquish_promises.contains(request_id)

  fun ref process_stream_notify_response(request_id: ConnectorStreamNotify,
    can_use: Bool)
  =>
    try
      let promise = _pending_notify_promises(request_id)?
      promise(can_use, point_of_reference)
    end

  fun ref process_stream_relinquish_response(
    request_id: ConnectorStreamRelinquish,
    relinquish: Bool)
  =>
    try
      let promise = _pending_relinquish_promises(request_id)?
      promise(relinquish)
    end

  fun ref complete_leader_state_relinquish(new_leader_name: WorkerName) =>
    _relinquish_leader_state(new_leader_name)

  fun ref _relinquish_leader_state(new_leader_name: WorkerName) =>
    _active_stream_map = Map[U64, WorkerName]()
    _inactive_stream_map = Map[U64, U64]()
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
    _active_stream_map = Map[U64, WorkerName]()
    _inactive_stream_map = Map[U64, StreamTuple]()
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
    let active_stream_map_copy = recover trn Map[U64, WorkerName] end
    for (k,v) in _active_stream_map.pairs() do
      active_stream_map_copy(k) = v
    end
    let inactive_stream_map_copy = recover trn Map[U64, U64] end
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

class LocalConnectorStreamRegistry[In: Any val]
  var global_registry: GlobalConnectorStreamRegistry

  // (stream_name, connector_source, last_acked_por, last_seen_por)
  let active_streams: Map[U64, (String, Any tag, U64, U64)] =
    active_streams.create()

  new create(global: GlobalConnectorStreamRegistry[In] ref) =>
    global_registry = global

  fun ref stream_is_present(stream_id: U64): Bool =>
    active_streams.contains(stream_id)

  // TODO [source-migration] put session tag back in here?
  // and thread it throughout all the way back to response from leader
  fun ref stream_notify(session_tag: USize,
    stream_id: U64, request_id: ConnectorStreamNotify,
    promise: Promise[NotifyResult], connector_source: ConectorSource[In] tag)
  =>
    // stream_id in active_streams.contains()?
    try
      (let stream_name: String, let tag_or_none: Any tag,
       let last_acked: U64, let last_seen: U64) = active_streams(stream_id)?
      // connector_source == active_streams(stream_id).connector_source?
      if tag_or_none == connector_source then
        // accept: already owned by requesting source
        promise(NotifyResult(connector_source, session_tag, true,
          last_acked, last_seen))
      else
        // reject: owned by another source in this registry
        promise(NotifyResult(connector_source, session_tag, false,
          last_acked, last_seen))
      end
    else
      // defer to global
      global_registry.stream_notify(session_tag, stream_id, request_id,
        promise)
    end

  fun ref stream_notify_result(session_tag: USize, stream_id: U64,
    promise: Promise[NotiyResult], connector_source: ConnectorSource[in] tag,
    success: Bool, last_acked: U64)
  =>
    if success then
      // double check it's safe to update locally
      Invariant(not active_streams.contains(steam_id))
      // update local data
      active_streams(stream_id) = (

  fun ref stream_update(stream_id: U64, checkpoint_id: CheckpointId,
    last_acked_por: U64, last_seen_por: U64,
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


class val ConnectorStreamNotify is Equatable[ConnectorStreamNotify]
  let stream_id: U64
  let session_id: RoutingId

  new val create(stream_id': U64, session_id': RoutingId) =>
    stream_id = stream_id'
    session_id = session_id'

  fun eq(that: ConnectorStreamNotify box): Bool =>
     """
    Returns true if the request is for the same session and stream.
    """
    (session_id == that.session_id) and (stream_id == that.stream_id)

  fun hash(): USize =>
    session_id.hash() xor stream_id.hash()


class val ConnectorStreamRelinquish is
    Equatable[ConnectorRelinquishStreamRequest]
  let stream_id: U64
  let session_id: RoutingId

  new val create(stream_id': U64, session_id': RoutingId) =>
    stream_id = stream_id'
    session_id = session_id'


  fun eq(that: ConnectorStreamRelinquish box): Bool =>
     """
    Returns true if the request is for the same session and stream.
    """
    (session_id == that.session_id) and (stream_id == that.stream_id)

  fun hash(): USize =>
    session_id.hash() xor stream_id.hash()
