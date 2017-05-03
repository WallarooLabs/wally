use "collections"
use "time"
use "sendence/rand"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/recovery"

class WActorRegistry
  let _actors: Map[WActorId, WActorWrapper tag] = _actors.create()
  let _roles: Map[String, Role] = _roles.create()
  let _rand: Rand

  new create(seed: U64 = Time.micros()) =>
    _rand = Rand(seed)

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

  fun ref send_to(target: WActorId, msg: WMessage val) ? =>
    _actors(target).receive(msg)

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
  let _auth: AmbientAuth
  let _initializer: WActorInitializer
  let _event_log: EventLog
  let _actors: Map[WActorId, WActorWrapper tag] = _actors.create()
  let _roles: Map[String, SetIs[WActorId]] = _roles.create()
  let _rand: Rand

  new create(auth: AmbientAuth, init: WActorInitializer, event_log: EventLog,
    seed: U64)
  =>
    _auth = auth
    _initializer = init
    _event_log = event_log
    _rand = Rand(seed)

  be create_actor(builder: WActorWrapperBuilder) =>
    let new_actor = builder(this, _auth, _event_log, _rand.u64())
    _initializer.add_actor(builder)

  be forget_actor(id: WActorId) =>
    try
      _actors.remove(id)
      for (r, s) in _roles.pairs() do
        s.unset(id)
        if s.size() == 0 then
          _roles.remove(r)
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
    for (k, set) in _roles.pairs() do
      for a in set.values() do
        w_actor.register_as_role(k, a)
      end
    end

  // TODO: Using a String to identify a role seems like a brittle approach
  be register_as_role(role: String, w_actor: WActorId) =>
    try
      if _roles.contains(role) then
        _roles(role).set(w_actor)
      else
        let new_role = SetIs[WActorId]
        new_role.set(w_actor)
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

class Role
  let _name: String
  let _actors: Array[WActorId] = _actors.create()
  let _rand: Rand

  new create(name': String, seed: U64) =>
    _name = name'
    _rand = Rand(seed)

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
