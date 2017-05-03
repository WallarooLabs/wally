use "collections"
use "sendence/guid"
use "wallaroo/fail"
use "wallaroo/recovery"
use "wallaroo/routing"

trait WActorWrapper
  be receive(msg: WMessage val)
  be process(data: Any val)
  be register_actor(id: WActorId, w_actor: WActorWrapper tag)
  be register_as_role(role: String, w_actor: WActorId)
  be tick()
  be create_actor(builder: WActorBuilder)
  be forget_actor(id: WActorId)
  fun ref _register_as_role(role: String)
  fun ref _send_to(target: WActorId, data: Any val)
  fun ref _send_to_role(role: String, data: Any val)
  fun ref _set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  fun ref _cancel_timer(t: WActorTimer)
  fun _known_actors(): Array[WActorId] val
  // Temporary for demonstration
  be pickle(m: SerializeTarget)

actor WActorWithState is WActorWrapper
  let _id: U128
  let _event_log: EventLog
  let _guid_gen: GuidGenerator = GuidGenerator
  let _auth: AmbientAuth
  let _actor_registry: WActorRegistry
  let _central_actor_registry: CentralWActorRegistry
  var _w_actor: WActor = EmptyWActor
  var _w_actor_id: WActorId
  var _helper: WActorHelper = EmptyWActorHelper
  let _timers: WActorTimers = WActorTimers

  var _seq_id: SeqId = 0

  new create(id: U128, w_actor_builder: WActorBuilder val, event_log: EventLog,
    r: CentralWActorRegistry, seed: U64, auth: AmbientAuth)
  =>
    _id = id
    _auth = auth
    _event_log = event_log
    _actor_registry = WActorRegistry(seed)
    _central_actor_registry = r
    _w_actor_id = WActorId(this)
    _helper = LiveWActorHelper(this)
    _w_actor = w_actor_builder(id, _helper)
    _central_actor_registry.register_actor(_w_actor_id, this)
    _event_log.register_origin(this, id)

  be receive(msg: WMessage val) =>
    """
    Called when receiving a message from another WActor
    """
    _w_actor.receive(msg.sender, msg.payload, _helper)
    _seq_id = _seq_id + 1
    _save_state()

  be process(data: Any val) =>
    """
    Called when receiving data from a Wallaroo pipeline
    """
    _w_actor.process(data, _helper)
    _seq_id = _seq_id + 1
    _save_state()

  be register_actor(id: WActorId, w_actor: WActorWrapper tag) =>
    _actor_registry.register_actor(id, w_actor)

  be register_as_role(role: String, w_actor: WActorId) =>
    _actor_registry.register_as_role(role, w_actor)

  be tick() =>
    """
    A tick is sent out once a second to all w_actors
    This won't scale if there are lots of w_actors
    """
    _timers.tick()

  // Temporary for demonstration
  be pickle(m: SerializeTarget) =>
    try
      let serialized = Pickle[WActor](_w_actor, _auth)
      m.add_serialized(serialized)
    else
      @printf[I32]("Did you save a reference to WActorHelper on a WActor definition? That will cause serialization to fail.\n".cstring())
      Fail()
    end

  be create_actor(builder: WActorBuilder) =>
    let new_builder = StatefulWActorWrapperBuilder(_guid_gen.u128(),
      builder)
    _central_actor_registry.create_actor(new_builder)

  be forget_actor(id: WActorId) =>
    _central_actor_registry.forget_actor(id)

  be replay_log_entry(uid: U128, frac_ids: None, statechange_id: U64,
    payload: ByteSeq)
  =>
    try
      _w_actor = Unpickle[WActor](payload, _auth)
    else
      Fail()
    end

  be log_flushed(low_watermark: SeqId) =>
    None

  fun ref _save_state() =>
    try
      let pickled = Pickle[WActor](_w_actor, _auth)
      let payload: Array[ByteSeq] iso =
        recover [pickled] end
      _event_log.queue_log_entry(_id, _guid_gen.u128(), None, 0, _seq_id,
        consume payload)
      _event_log.flush_buffer(_id, _seq_id)
    else
      Fail()
    end

  fun ref _register_as_role(role: String) =>
    _central_actor_registry.register_as_role(role, _w_actor_id)

  fun ref _send_to(target: WActorId, data: Any val) =>
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
      Fail()
    end

  fun ref _set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  =>
    let timer = WActorTimer(duration, callback, is_repeating)
    _timers.set_timer(timer)
    timer

  fun ref _cancel_timer(t: WActorTimer) =>
    _timers.cancel_timer(t)

  fun _known_actors(): Array[WActorId] val =>
    _actor_registry.known_actors()

interface val WActorWrapperBuilder
  fun apply(r: CentralWActorRegistry, auth: AmbientAuth, event_log: EventLog,
    seed: U64): WActorWrapper tag

class val StatefulWActorWrapperBuilder
  let _id: U128
  let _w_actor_builder: WActorBuilder val

  new val create(id: U128, wab: WActorBuilder val) =>
    _id = id
    _w_actor_builder = wab

  fun apply(r: CentralWActorRegistry, auth: AmbientAuth, event_log: EventLog,
    seed: U64): WActorWrapper tag
  =>
    WActorWithState(_id, _w_actor_builder, event_log, r, seed, auth)

class val WActorId is Equatable[WActorId]
  let _w_actor_hash: U64

  new val create(w_actor: WActorWrapper tag) =>
    _w_actor_hash = (digestof w_actor).hash()

  fun eq(that: box->WActorId): Bool =>
    _w_actor_hash is that._w_actor_hash

  fun hash(): U64 =>
    _w_actor_hash.hash()

//Temporary for demo
interface tag SerializeTarget
  be add_serialized(s: ByteSeq val)

class LiveWActorHelper is WActorHelper
  let _w_actor: WActorWrapper ref

  new create(w_actor: WActorWrapper ref) =>
    _w_actor = w_actor

  fun ref send_to(target: WActorId, data: Any val) =>
    _w_actor._send_to(target, data)

  fun ref send_to_role(role: String, data: Any val) =>
    _w_actor._send_to_role(role, data)

  fun ref register_as_role(role: String) =>
    _w_actor._register_as_role(role)

  fun ref create_actor(builder: WActorBuilder) =>
    _w_actor.create_actor(builder)

  fun ref destroy_actor(id: WActorId) =>
    _w_actor.forget_actor(id)

  fun known_actors(): Array[WActorId] val =>
    _w_actor._known_actors()

  fun ref set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  =>
    _w_actor._set_timer(duration, callback, is_repeating)

  fun ref cancel_timer(t: WActorTimer) =>
    _w_actor._cancel_timer(t)

class EmptyWActorHelper is WActorHelper
  fun ref send_to(target: WActorId, data: Any val) =>
    None

  fun ref send_to_role(role: String, data: Any val) =>
    None

  fun ref register_as_role(role: String) =>
    None

  fun ref create_actor(builder: WActorBuilder) =>
    None

  fun ref destroy_actor(id: WActorId) =>
    None

  fun known_actors(): Array[WActorId] val =>
    recover Array[WActorId] end

  fun ref set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  =>
    WActorTimer(0, {() => None} ref)

  fun ref cancel_timer(t: WActorTimer) =>
    None
