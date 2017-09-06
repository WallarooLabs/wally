/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "sendence/guid"
use "wallaroo/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/watermarking"
use "wallaroo/ent/w_actor/broadcast"
use "wallaroo/fail"
use "wallaroo/routing"
use "wallaroo/sink"
use "wallaroo/topology"

trait WActorWrapper
  be receive(msg: WMessage val)
  be process(data: Any val)
  be register_actor(id: U128, w_actor: WActorWrapper tag)
  be register_actor_for_worker(id: U128, worker: String)
  be register_as_role(role: String, w_actor: U128)
  be register_sinks(s: Array[Sink] val)
  be tick()
  be create_actor(builder: WActorBuilder)
  be forget_actor(id: U128)
  be forward_to(target: U128, sender: U128, data: Any val)
  be forward_to_role(role: String, sender: U128, data: Any val)
  be forget_external_actor(id: U128)
  be broadcast_variable_update(k: String, v: Any val)
  fun ref _register_as_role(role: String)
  fun ref _send_to(target: U128, data: Any val)
  fun ref _send_to_role(role: String, data: Any val)
  fun ref _send_to_sink[Out: Any val](sink_id: USize, output: Out)
  fun ref _roles_for(w_actor: U128): Array[String]
  fun ref _actors_in_role(role: String): Array[U128]
  fun ref _create_actor(builder: WActorBuilder)
  fun ref _update_actor_being_created(new_actor: WActorWrapper tag)
  fun ref _forget_actor(id: U128)
  fun ref _subscribe_to_broadcast_variable(k: String)
  fun ref _read_broadcast_variable(k: String): (Any val | None)
  fun ref _update_broadcast_variable(k: String, v: Any val)
  fun ref _set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  fun ref _cancel_timer(t: WActorTimer)

actor WActorWithState is WActorWrapper
  let _worker_name: String
  let _id: U128
  let _event_log: EventLog
  let _guid_gen: GuidGenerator = GuidGenerator
  let _auth: AmbientAuth
  let _actor_registry: WActorRegistry
  let _central_actor_registry: CentralWActorRegistry
  var _sinks: Array[Sink] val = recover Array[Sink] end
  var _w_actor: WActor = EmptyWActor
  var _w_actor_id: U128
  var _helper: WActorHelper = EmptyWActorHelper
  let _timers: WActorTimers = WActorTimers

  let _broadcast_variables: BroadcastVariables
  let _broadcast_variable_map: Map[String, Any val] =
    _broadcast_variable_map.create()

  // TODO: Find a way to eliminate this
  let _dummy_actor_producer: _DummyActorProducer = _DummyActorProducer

  var _seq_id: SeqId = 0

  // Used to indicate if we have created a new w_actor in the middle of
  // processing/receiving a message from outside this w_actor. We need to
  // treat that as a special case or else there's a race condition in
  // sending messages to any role that's exclusively inhabited by the
  // new w_actor.
  var _creating_actor: Bool = false
  var _actor_being_created: WActorWrapper tag

  new create(worker: String, id: U128, w_actor_builder: WActorBuilder,
    event_log: EventLog, r: CentralWActorRegistry,
    actor_to_worker_map: Map[U128, String] val, connections: Connections,
    broadcast_variables: BroadcastVariables,
    boundaries: Map[String, OutgoingBoundary] val, seed: U64,
    auth: AmbientAuth)
  =>
    _worker_name = worker
    _id = id
    _auth = auth
    _event_log = event_log
    _central_actor_registry = r
    _actor_being_created = this
    _actor_registry = WActorRegistry(_worker_name, _auth, _event_log,
      _central_actor_registry, actor_to_worker_map, connections,
      broadcast_variables, boundaries, seed)
    _w_actor_id = id
    _broadcast_variables = broadcast_variables
    _helper = LiveWActorHelper(this)
    _w_actor = w_actor_builder(id, _helper)
    _central_actor_registry.register_actor(_w_actor_id, this)
    _event_log.register_producer(this, id)

  be receive(msg: WMessage val) =>
    """
    Called when receiving a message from another WActor
    """
    _creating_actor = false
    ifdef "trace" then
      @printf[I32]("receive() called at WActor %s\n".cstring(),
        _id.string().cstring())
    end
    _w_actor.receive(msg.sender, msg.payload, _helper)
    _seq_id = _seq_id + 1
    _save_state()

  be process(data: Any val) =>
    """
    Called when receiving data from a Wallaroo pipeline
    """
    _creating_actor = false
    ifdef "trace" then
      @printf[I32]("process() called at WActor %s\n".cstring(),
        _id.string().cstring())
    end
    _w_actor.process(data, _helper)
    _seq_id = _seq_id + 1
    _save_state()

  be register_actor(id: U128, w_actor: WActorWrapper tag) =>
    _actor_registry.register_actor(id, w_actor)

  be register_actor_for_worker(id: U128, worker: String) =>
    _actor_registry.register_actor_for_worker(id, worker)

  be register_as_role(role: String, w_actor: U128) =>
    _actor_registry.register_as_role(role, w_actor)

  be register_sinks(s: Array[Sink] val) =>
    _sinks = s

  be tick() =>
    """
    A tick is sent out once a second to all w_actors
    This won't scale if there are lots of w_actors
    """
    _timers.tick()

  be create_actor(builder: WActorBuilder) =>
    _create_actor(builder)

  be broadcast_variable_update(k: String, v: Any val) =>
    _broadcast_variable_map(k) = v
    _w_actor.receive_broadcast_variable_update(k, v)

  fun ref _create_actor(builder: WActorBuilder) =>
    _actor_registry.create_actor(builder, this)
    _creating_actor = true

  fun ref _update_actor_being_created(new_actor: WActorWrapper tag) =>
    _actor_being_created = new_actor

  be forget_actor(id: U128) =>
    _forget_actor(id)

  fun ref _forget_actor(id: U128) =>
    _actor_registry.forget_actor(id)
    _central_actor_registry.forget_actor(id)

  be forget_external_actor(id: U128) =>
    _actor_registry.remove_actor_from_worker_map(id)

  be forward_to(target: U128, sender: U128, data: Any val) =>
    try
      let wrapped = WMessage(sender, target, data)
      _actor_registry.send_to(target, wrapped)
    else
      Fail()
    end

  be forward_to_role(role: String, sender: U128, data: Any val) =>
    try
      _actor_registry.send_to_role(role, sender, data)
    else
      _central_actor_registry.send_to_role(role, sender, data)
    end

  be replay_log_entry(uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq)
  =>
    try
      _w_actor = Unpickle[WActor](payload, _auth)
    else
      Fail()
    end

  be initialize_seq_id_on_recovery(seq_id: SeqId) =>
    None

  be log_flushed(low_watermark: SeqId) =>
    None

  fun ref _save_state() =>
    try
      let pickled = Pickle[WActor](_w_actor, _auth)
      let payload: Array[ByteSeq] iso =
        recover [pickled] end
      _event_log.queue_log_entry(_id, _guid_gen.u128(), None,
        U64.max_value(), _seq_id, consume payload)
      _event_log.flush_buffer(_id, _seq_id)
    else
      Fail()
    end

  fun ref _register_as_role(role: String) =>
    _central_actor_registry.register_as_role(role, _w_actor_id)

  fun ref _send_to(target: U128, data: Any val) =>
    try
      let wrapped = WMessage(_w_actor_id, target, data)
      _actor_registry.send_to(target, wrapped)
    else
      Fail()
    end

  fun ref _send_to_role(role: String, data: Any val) =>
    try
      _actor_registry.send_to_role(role, _w_actor_id, data)
    else
      if _creating_actor then
        // TODO: This still leaves a potential race condition in place. If you
        // create two or more actors per one external message, this will
        // forward through the last one you created.  If the first one
        // failed to register itself ast his role at the central actor
        // registry before the later one forwards the message to that
        // registry, then we might fail due to no one inhabiting the role.
        // My tests do not show this actually happening so far.
        // See issue #974.
        _actor_being_created.forward_to_role(role, _w_actor_id, data)
      else
        _central_actor_registry.send_to_role(role, _w_actor_id, data)
      end
    end

  fun ref _send_to_sink[Out: Any val](sink_id: USize, output: Out) =>
    try
      // TODO: Should we create a separate Sink method for when we're not
      // using the pipeline metadata?  Or do we create the same metadata
      // for actor system messages.
      _sinks(sink_id).run[Out]("", 0, output, _dummy_actor_producer,
        0, None, 0, 0, 0, 0, 0)
    else
      @printf[I32]("Attempting to send to nonexistent sink id!\n".cstring())
      Fail()
    end

  fun ref _roles_for(w_actor: U128): Array[String] =>
    _actor_registry.roles_for(w_actor)

  fun ref _actors_in_role(role: String): Array[U128] =>
    _actor_registry.actors_in_role(role)

  fun ref _subscribe_to_broadcast_variable(k: String) =>
    _broadcast_variables.subscribe_to(k, this)

  fun ref _read_broadcast_variable(k: String): (Any val | None) =>
    try
      _broadcast_variable_map(k)
    else
      None
    end

  fun ref _update_broadcast_variable(k: String, v: Any val) =>
    _broadcast_variable_map(k) = v
    _broadcast_variables.update(k, v, this)

  fun ref _set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  =>
    let timer = WActorTimer(duration, callback, is_repeating)
    _timers.set_timer(timer)
    timer

  fun ref _cancel_timer(t: WActorTimer) =>
    _timers.cancel_timer(t)

interface val WActorWrapperBuilder
  fun apply(worker: String, r: CentralWActorRegistry, auth: AmbientAuth,
    event_log: EventLog, actor_to_worker_map: Map[U128, String] val,
    connections: Connections, broadcast_variables: BroadcastVariables,
    boundaries: Map[String, OutgoingBoundary] val,
    seed: U64): WActorWrapper tag
  fun id(): U128

class val StatefulWActorWrapperBuilder
  let _id: U128
  let _w_actor_builder: WActorBuilder

  new val create(id': U128, wab: WActorBuilder) =>
    _id = id'
    _w_actor_builder = wab

  fun apply(worker: String, r: CentralWActorRegistry, auth: AmbientAuth,
    event_log: EventLog, actor_to_worker_map: Map[U128, String] val,
    connections: Connections, broadcast_variables: BroadcastVariables,
    boundaries: Map[String, OutgoingBoundary] val,
    seed: U64): WActorWrapper tag
  =>
    WActorWithState(worker, _id, _w_actor_builder, event_log, r,
      actor_to_worker_map, connections, broadcast_variables, boundaries, seed,
      auth)

  fun id(): U128 =>
    _id

class LiveWActorHelper is WActorHelper
  let _w_actor: WActorWrapper ref

  new create(w_actor: WActorWrapper ref) =>
    _w_actor = w_actor

  fun ref send_to(target: U128, data: Any val) =>
    _w_actor._send_to(target, data)

  fun ref send_to_role(role: String, data: Any val) =>
    _w_actor._send_to_role(role, data)

  fun ref send_to_sink[Out: Any val](sink_id: USize, output: Out) =>
    _w_actor._send_to_sink[Out](sink_id, output)

  fun ref register_as_role(role: String) =>
    _w_actor._register_as_role(role)

  fun ref roles_for(w_actor: U128): Array[String] =>
    _w_actor._roles_for(w_actor)

  fun ref actors_in_role(role: String): Array[U128] =>
    _w_actor._actors_in_role(role)

  fun ref create_actor(builder: WActorBuilder) =>
    _w_actor._create_actor(builder)

  fun ref destroy_actor(id: U128) =>
    _w_actor._forget_actor(id)

  fun ref subscribe_to_broadcast_variable(k: String) =>
    _w_actor._subscribe_to_broadcast_variable(k)

  fun ref read_broadcast_variable(k: String): (Any val | None) =>
    _w_actor._read_broadcast_variable(k)

  fun ref update_broadcast_variable(k: String, v: Any val) =>
    _w_actor._update_broadcast_variable(k, v)

  fun ref set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  =>
    _w_actor._set_timer(duration, callback, is_repeating)

  fun ref cancel_timer(t: WActorTimer) =>
    _w_actor._cancel_timer(t)

class EmptyWActorHelper is WActorHelper
  fun ref send_to(target: U128, data: Any val) =>
    None

  fun ref send_to_role(role: String, data: Any val) =>
    None

  fun ref send_to_sink[Out: Any val](sink_id: USize, output: Out) =>
    None

  fun ref register_as_role(role: String) =>
    None

  fun ref roles_for(w_actor: U128): Array[String] =>
    Array[String]

  fun ref actors_in_role(role: String): Array[U128] =>
    Array[U128]

  fun ref create_actor(builder: WActorBuilder) =>
    None

  fun ref destroy_actor(id: U128) =>
    None

  fun ref subscribe_to_broadcast_variable(k: String) =>
    None

  fun ref read_broadcast_variable(k: String): (Any val | None) =>
    None

  fun ref update_broadcast_variable(k: String, v: Any val) =>
    None

  fun ref set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  =>
    WActorTimer(0, {() => None} ref)

  fun ref cancel_timer(t: WActorTimer) =>
    None

actor _DummyActorProducer is Producer
  be mute(c: Consumer) =>
    None

  be unmute(c: Consumer) =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): SeqId =>
    0

  fun ref current_sequence_id(): SeqId =>
    0

  fun ref _acker(): Acker =>
    Acker

  fun ref flush(low_watermark: SeqId) =>
    None

  fun ref update_router(router: Router) =>
    None

  be request_ack() =>
    None
