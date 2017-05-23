use "collections"
use "time"
use "sendence/rand"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/recovery"
use "wallaroo/tcp_sink"

class WActorRegistry
  let _worker_name: String
  let _auth: AmbientAuth
  let _actor_to_worker_map: Map[U128, String] = _actor_to_worker_map.create()
  let _actors: Map[WActorId, WActorWrapper tag] = _actors.create()
  let _roles: Map[String, Role] = _roles.create()
  var _boundaries: Map[String, OutgoingBoundary] val
  let _rand: EnhancedRandom

  new create(worker: String, auth: AmbientAuth,
    actor_to_worker: Map[U128, String] val,
    boundaries: Map[String, OutgoingBoundary] val, seed: U64 = Time.micros())
  =>
    _worker_name = worker
    _auth = auth
    for (k, v) in actor_to_worker.pairs() do
      _actor_to_worker_map(k) = v
    end
    _boundaries = boundaries
    _rand = EnhancedRandom(seed)

  fun ref update_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    _boundaries = bs

  fun ref register_actor(id: WActorId, w_actor: WActorWrapper tag) =>
    _actors(id) = w_actor

  fun ref register_as_role(role: String, w_actor: WActorId) =>
    try
      if _roles.contains(role) then
        _roles(role).register_actor(w_actor)
      else
        let new_role = Role(role, _rand.u64())
        new_role.register_actor(w_actor)
        _roles(role) = new_role
      end
    else
      Fail()
    end

  fun ref forget_actor(id: WActorId) =>
    try
      _actors.remove(id)
      for (k, v) in _roles.pairs() do
        try
          let idx = v.actors().find(id)
          v.actors().remove(idx, 1)
        end
        if v.empty() then
          _roles.remove(k)
        end
      end
    else
      ifdef debug then
        @printf[I32]("Tried to forget unknown actor\n".cstring())
      end
    end

  fun ref send_to(target_id: WActorId, msg: WMessage val) ? =>
    let target_worker = _actor_to_worker_map(target_id.id())
    if target_worker == _worker_name then
      _actors(target_id).receive(msg)
    else
      let a_msg = ActorDeliveryMsg(_worker_name, target_id, msg.payload,
        msg.sender)
      _boundaries(target_worker).forward_actor_data(a_msg)
    end

  fun ref send_to_role(role: String, sender: WActorId,
    data: Any val) ?
  =>
    let target = _roles(role).next()
    let wrapped = WMessage(sender, target, data)
    send_to(target, wrapped)

  fun broadcast(data: Any val) =>
    for target in _actors.values() do
      target.process(data)
    end

  fun known_actors(): Array[WActorId] val =>
    let kas: Array[WActorId] trn = recover Array[WActorId] end
    for a in _actors.keys() do
      kas.push(a)
    end
    consume kas

actor CentralWActorRegistry
  let _worker_name: String
  let _auth: AmbientAuth
  let _initializer: WActorInitializer
  var _sinks: Array[TCPSink] val
  let _event_log: EventLog
  let _actors: Map[WActorId, WActorWrapper tag] = _actors.create()
  let _role_sets: Map[String, SetIs[WActorId]] = _role_sets.create()
  let _roles: Map[String, Role] = _roles.create()
  var _actor_to_worker_map: Map[U128, String] val =
    recover Map[U128, String] end
  var _boundaries: Map[String, OutgoingBoundary] val =
    recover Map[String, OutgoingBoundary] end
  let _rand: EnhancedRandom

  new create(worker: String, auth: AmbientAuth, init: WActorInitializer,
    sinks: Array[TCPSink] val, event_log: EventLog, seed: U64)
  =>
    _worker_name = worker
    _auth = auth
    _initializer = init
    _sinks = sinks
    _event_log = event_log
    _rand = EnhancedRandom(seed)

  be update_sinks(s: Array[TCPSink] val) =>
    _sinks = s

  be update_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    _boundaries = bs

  be update_actor_to_worker_map(actor_to_worker_map: Map[U128, String] val) =>
    _actor_to_worker_map = actor_to_worker_map

  be create_actor(builder: WActorWrapperBuilder) =>
    //TODO: Use persistent map to improve perf
    let new_actor_to_worker: Map[U128, String] trn =
      recover Map[U128, String] end
    for (k, v) in _actor_to_worker_map.pairs() do
      new_actor_to_worker(k) = v
    end
    new_actor_to_worker(builder.id()) = _worker_name
    _actor_to_worker_map = consume new_actor_to_worker

    let new_actor = builder(_worker_name, this, _auth, _event_log,
      _actor_to_worker_map, _boundaries, _rand.u64())
    _initializer.add_actor(builder)

  be forget_actor(id: WActorId) =>
    try
      _actors.remove(id)
      for (r, s) in _role_sets.pairs() do
        s.unset(id)
        if s.size() == 0 then
          _role_sets.remove(r)
        end
      end
      for (k, v) in _roles.pairs() do
        try
          let idx = v.actors().find(id)
          v.actors().remove(idx, 1)
        end
        if v.empty() then
          _roles.remove(k)
        end
      end
      for a in _actors.values() do
        a.forget_actor(id)
      end
    else
      ifdef debug then
        @printf[I32]("Tried to forget unknown actor\n".cstring())
      end
    end

  be register_actor(id: WActorId, w_actor: WActorWrapper tag) =>
    _actors(id) = w_actor
    for (k, v) in _actors.pairs() do
      v.register_actor(id, w_actor)
      w_actor.register_actor(k, v)
    end
    for (k, set) in _role_sets.pairs() do
      for a in set.values() do
        w_actor.register_as_role(k, a)
      end
    end
    w_actor.register_sinks(_sinks)

  // TODO: Using a String to identify a role seems like a brittle approach
  be register_as_role(role: String, w_actor: WActorId) =>
    try
      if _role_sets.contains(role) then
        _role_sets(role).set(w_actor)
      else
        let new_role = SetIs[WActorId]
        new_role.set(w_actor)
        _role_sets(role) = new_role
      end

      if _roles.contains(role) then
        _roles(role).register_actor(w_actor)
      else
        let new_role = Role(role, _rand.u64())
        new_role.register_actor(w_actor)
        _roles(role) = new_role
      end

      for a in _actors.values() do
        a.register_as_role(role, w_actor)
      end
    else
      Fail()
    end

  be tick() =>
    for a in _actors.values() do
      a.tick()
    end

  be broadcast(data: Any val) =>
    for target in _actors.values() do
      target.process(data)
    end

  be broadcast_to_role(role: String, data: Any val) =>
    try
      for target_id in _role_sets(role).values() do
        _actors(target_id).process(data)
      end
    else
      @printf[I32]("Trying to broadcast to nonexistent role %s!\n".cstring(),
        role.cstring())
    end

  be send_for_process(target_id: WActorId, data: Any val) =>
    try
      _actors(target_id).process(data)
    else
      Fail()
    end

  be send_to(target_id: WActorId, msg: WMessage val) =>
    try
      let target_worker = _actor_to_worker_map(target_id.id())
      if target_worker == _worker_name then
        _actors(target_id).receive(msg)
      else
        let a_msg = ActorDeliveryMsg(_worker_name, target_id, msg.payload,
          msg.sender)
        _boundaries(target_worker).forward_actor_data(a_msg)
      end
    else
      Fail()
    end

  be send_to_role(role: String, data: Any val) =>
    try
      let target_id = _roles(role).next()
      let target = _actors(target_id)
      target.process(data)
    else
      @printf[I32]("Trying to send to nonexistent role!\n".cstring())
    end

class Role
  let _name: String
  let _actors: Array[WActorId] = _actors.create()
  let _rand: EnhancedRandom

  new create(name': String, seed: U64) =>
    _name = name'
    _rand = EnhancedRandom(seed)

  fun name(): String =>
    _name

  fun empty(): Bool => _actors.size() == 0

  fun ref actors(): Array[WActorId] => _actors

  fun ref register_actor(w_actor: WActorId) =>
    if not _actors.contains(w_actor) then
      _actors.push(w_actor)
    end

  fun ref next(): WActorId ? =>
    _rand.pick[WActorId](_actors)
