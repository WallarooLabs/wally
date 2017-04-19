use "collections"
use "time"
use "sendence/rand"
use "wallaroo/fail"
use "wallaroo/invariant"

class WActorRegistry
  let _actors: Map[WActorId, WActorWrapper tag] = _actors.create()
  let _roles: Map[String, Role] = _roles.create()
  let _rand: Rand

  new create(seed: U64 = Time.micros()) =>
    _rand = Rand(seed)

  fun ref register_actor(id: WActorId, w_actor: WActorWrapper tag)
  =>
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
  let _actors: Map[WActorId, WActorWrapper tag] = _actors.create()
  let _roles: Map[String, SetIs[WActorId]] = _roles.create()

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
      // ifdef debug then
      //   Invariant(_actors.contains(w_actor))
      // end

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

  fun ref register_actor(w_actor: WActorId) =>
    if not _actors.contains(w_actor) then
      _actors.push(w_actor)
    end

  fun ref next(): WActorId ? =>
    _rand.pick[WActorId](_actors)
