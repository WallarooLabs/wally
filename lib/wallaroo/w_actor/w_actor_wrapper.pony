use "collections"
use "wallaroo/fail"

trait WActorWrapper
  be receive(msg: WMessage val)
  be process(data: Any val)
  be register_actor(id: WActorId, w_actor: WActorWrapper tag)
  be register_as_role(role: String, w_actor: WActorId)
  be tick()
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
  let _auth: AmbientAuth
  let _actor_registry: WActorRegistry
  let _central_actor_registry: CentralWActorRegistry
  var _w_actor: WActor = EmptyWActor
  var _w_actor_id: WActorId
  let _timers: WActorTimers = WActorTimers

  new create(id: U128, w_actor_builder: WActorBuilder val,
    r: CentralWActorRegistry, seed: U64, auth: AmbientAuth)
  =>
    _id = id
    _auth = auth
    _actor_registry = WActorRegistry(seed)
    _central_actor_registry = r
    _w_actor_id = WActorId(this)
    let helper = WActorHelper(this)
    _w_actor = w_actor_builder(id, helper)
    _central_actor_registry.register_actor(_w_actor_id, this)

  be receive(msg: WMessage val) =>
    """
    Called when receiving a message from another WActor
    """
    _w_actor.receive(msg.sender, msg.payload)

  be process(data: Any val) =>
    """
    Called when receiving data from a Wallaroo pipeline
    """
    _w_actor.process(data)

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
  fun apply(r: CentralWActorRegistry, auth: AmbientAuth, seed: U64):
    WActorWrapper tag

class val StatefulWActorWrapperBuilder
  let _id: U128
  let _w_actor_builder: WActorBuilder val

  new val create(id: U128, wab: WActorBuilder val) =>
    _id = id
    _w_actor_builder = wab

  fun apply(r: CentralWActorRegistry, auth: AmbientAuth,
    seed: U64): WActorWrapper tag
  =>
    WActorWithState(_id, _w_actor_builder, r, seed, auth)

class val WActorId is Equatable[WActorId]
  let _w_actor: WActorWrapper tag

  new val create(w_actor: WActorWrapper tag) =>
    _w_actor = w_actor

  fun eq(that: box->WActorId): Bool =>
    _w_actor is that._w_actor

  fun hash(): U64 =>
    (digestof _w_actor).hash()

//Temporary for demo
interface tag SerializeTarget
  be add_serialized(s: Array[U8] val)

