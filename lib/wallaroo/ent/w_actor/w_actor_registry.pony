use "collections"
use "time"
use "sendence/guid"
use "sendence/rand"
use "wallaroo/boundary"
use "wallaroo/broadcast"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/ent/network"
use "wallaroo/recovery"
use "wallaroo/sink"
use "wallaroo/topology"

class WActorRegistry
  let _worker_name: String
  let _auth: AmbientAuth
  let _event_log: EventLog
  var _actor_to_worker_map: Map[U128, String] = _actor_to_worker_map.create()
  let _connections: Connections
  let _actors: Map[U128, WActorWrapper tag] = _actors.create()
  let _roles: Map[String, Role] = _roles.create()
  var _boundaries: Map[String, OutgoingBoundary] val
  let _broadcast_variables: BroadcastVariables

  let _central_actor_registry: CentralWActorRegistry
  let _rand: EnhancedRandom
  let _guid_gen: GuidGenerator = GuidGenerator

  new create(worker: String, auth: AmbientAuth, event_log: EventLog,
    central_actor_registry: CentralWActorRegistry,
    actor_to_worker: Map[U128, String] val, connections: Connections,
    broadcast_variables: BroadcastVariables,
    boundaries: Map[String, OutgoingBoundary] val, seed: U64 = Time.micros())
  =>
    _worker_name = worker
    _auth = auth
    _event_log = event_log
    _central_actor_registry = central_actor_registry
    for (k, v) in actor_to_worker.pairs() do
      _actor_to_worker_map(k) = v
    end
    _connections = connections
    _broadcast_variables = broadcast_variables
    _boundaries = boundaries
    _rand = EnhancedRandom(seed)

  fun ref update_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    _boundaries = bs

  fun ref register_actor_for_worker(id: U128, worker: String) =>
    //TODO: Use persistent map to improve perf
    let new_actor_to_worker = recover trn Map[U128, String] end
    for (k, v) in _actor_to_worker_map.pairs() do
      new_actor_to_worker(k) = v
    end
    new_actor_to_worker(id) = worker
    _actor_to_worker_map = consume new_actor_to_worker

  fun ref register_actor(id: U128, w_actor: WActorWrapper tag) =>
    _actors(id) = w_actor
    register_actor_for_worker(id, _worker_name)

  fun ref register_as_role(role: String, w_actor: U128) =>
    try
      if _roles.contains(role) then
        _roles(role).register_actor(w_actor)
      else
        let new_role = Role(role)
        new_role.register_actor(w_actor)
        _roles(role) = new_role
      end
    else
      Fail()
    end

  fun ref create_actor(builder: WActorBuilder, w_actor: WActorWrapper ref) =>
    let new_id = _guid_gen.u128()
    let new_builder = StatefulWActorWrapperBuilder(new_id, builder)

    //TODO: Use persistent map to improve perf
    let new_actor_to_worker = recover trn Map[U128, String] end
    for (k, v) in _actor_to_worker_map.pairs() do
      new_actor_to_worker(k) = v
    end

    let new_actor = new_builder(_worker_name, _central_actor_registry, _auth,
      _event_log, consume new_actor_to_worker, _connections,
      _broadcast_variables, _boundaries, _rand.u64())
    w_actor._update_actor_being_created(new_actor)

    register_actor(new_id, new_actor)
    _central_actor_registry.create_actor(new_actor, new_builder)

  fun ref forget_actor(id: U128) =>
    try
      _actors.remove(id)
      for (k, v) in _roles.pairs() do
        try
          v.remove_actor(id)
        end
        if v.empty() then
          _roles.remove(k)
        end
      end
      remove_actor_from_worker_map(id)
    else
      ifdef debug then
        @printf[I32]("Tried to forget unknown actor\n".cstring())
      end
    end

  fun ref remove_actor_from_worker_map(id: U128) =>
    try
      _actor_to_worker_map.remove(id)
    else
      @printf[I32]("Tried to destroy unknown actor.\n".cstring())
    end
    for w_actor in _actors.values() do
      w_actor.forget_external_actor(id)
    end

  fun ref send_to(target_id: U128, msg: WMessage val) ? =>
    let target_worker = _actor_to_worker_map(target_id)
    if target_worker == _worker_name then
      _actors(target_id).receive(msg)
    else
      let a_msg = ActorDeliveryMsg(_worker_name, target_id, msg.payload,
        msg.sender)
      _boundaries(target_worker).forward_actor_data(a_msg)
    end

  fun ref send_to_role(role: String, sender: U128,
    data: Any val) ?
  =>
    let target = _roles(role).next(_rand)
    let wrapped = WMessage(sender, target, data)
    send_to(target, wrapped)

  fun ref roles_for(w_actor: U128): Array[String] =>
    let roles = Array[String]
    for (r_name, role) in _roles.pairs() do
      if role.contains(w_actor) then
        roles.push(r_name)
      end
    end
    roles

  fun ref actors_in_role(role: String): Array[U128] =>
    try
      _roles(role).local_actors()
    else
      Array[U128]
    end

actor CentralWActorRegistry
  let _worker_name: String
  let _auth: AmbientAuth
  let _initializer: WActorInitializer
  var _sinks: Array[Sink] val
  let _event_log: EventLog
  let _actors: Map[U128, WActorWrapper tag] = _actors.create()
  let _role_sets: Map[String, SetIs[U128]] = _role_sets.create()
  let _roles: Map[String, Role] = _roles.create()
  var _actor_to_worker_map: Map[U128, String] val =
    recover Map[U128, String] end
  var _boundaries: Map[String, OutgoingBoundary] val =
    recover Map[String, OutgoingBoundary] end
  let _connections: Connections
  let _rand: EnhancedRandom

  new create(worker: String, auth: AmbientAuth, init: WActorInitializer,
    connections: Connections, sinks: Array[Sink] val, event_log: EventLog,
    seed: U64)
  =>
    _worker_name = worker
    _auth = auth
    _initializer = init
    _connections = connections
    _sinks = sinks
    _event_log = event_log
    _rand = EnhancedRandom(seed)

  be update_sinks(s: Array[Sink] val) =>
    _sinks = s

  be update_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    _boundaries = bs

  be update_actor_to_worker_map(actor_to_worker_map: Map[U128, String] val) =>
    _actor_to_worker_map = actor_to_worker_map

  be create_actor(w_actor: WActorWrapper tag, builder: WActorWrapperBuilder) =>
    _initializer.add_actor(builder)
    _register_actor(builder.id(), w_actor)

  be forget_actor(id: U128) =>
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
          v.remove_actor(id)
        end
        if v.empty() then
          _roles.remove(k)
        end
      end
      for a in _actors.values() do
        a.forget_actor(id)
      end
      _remove_actor_from_worker_map(id)

      // Notify cluster
      try
        let msg = ChannelMsgEncoder.forget_actor(id, _auth)
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end
    else
      ifdef debug then
        @printf[I32]("Tried to forget unknown actor\n".cstring())
      end
    end

  be forget_external_actor(id: U128) =>
    _remove_actor_from_worker_map(id)

  fun ref _remove_actor_from_worker_map(id: U128) =>
    //TODO: Use persistent map to improve perf
    let new_actor_to_worker = recover trn Map[U128, String] end
    for (k, v) in _actor_to_worker_map.pairs() do
      if k != id then
        new_actor_to_worker(k) = v
      end
    end
    _actor_to_worker_map = consume new_actor_to_worker
    for w_actor in _actors.values() do
      w_actor.forget_external_actor(id)
    end

  be register_actor_for_worker(id: U128, worker: String) =>
    _register_actor_for_worker(id, worker)

  fun ref _register_actor_for_worker(id: U128, worker: String) =>
    try
      if not (_actor_to_worker_map.contains(id) and
        (_actor_to_worker_map(id) == worker))
      then
        //TODO: Use persistent map to improve perf
        let new_actor_to_worker = recover trn Map[U128, String] end
        for (k, v) in _actor_to_worker_map.pairs() do
          new_actor_to_worker(k) = v
        end
        new_actor_to_worker(id) = worker
        _actor_to_worker_map = consume new_actor_to_worker
        for w_actor in _actors.values() do
          w_actor.register_actor_for_worker(id, worker)
        end
      end
    else
      Fail()
    end

  be register_actor(id: U128, w_actor: WActorWrapper tag) =>
    _register_actor(id, w_actor)

  fun ref _register_actor(id: U128, w_actor: WActorWrapper tag) =>
    if not _actors.contains(id) then
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
      _register_actor_for_worker(id, _worker_name)

      ifdef "trace" then
        @printf[I32]("Registering WActor %s\n".cstring(),
          id.string().cstring())
      end

      // Notify cluster
      try
        let msg = ChannelMsgEncoder.register_actor_for_worker(id, _worker_name,
          _auth)
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end
    end

  // TODO: Using a String to identify a role seems like a brittle approach
  be register_as_role(role: String, w_actor: U128, external: Bool = false)
  =>
    _register_as_role(role, w_actor, external)

  fun ref _register_as_role(role: String, w_actor: U128,
    external: Bool = false)
  =>
    try
      if not(_role_sets.contains(role) and _role_sets(role).contains(w_actor))
      then
        if _role_sets.contains(role) then
          _role_sets(role).set(w_actor)
        else
          let new_role = SetIs[U128]
          new_role.set(w_actor)
          _role_sets(role) = new_role
        end

        if _roles.contains(role) then
          _roles(role).register_actor(w_actor)
        else
          let new_role = Role(role)
          new_role.register_actor(w_actor)
          _roles(role) = new_role
        end

        for a in _actors.values() do
          a.register_as_role(role, w_actor)
        end

        _initializer.register_as_role(role, w_actor)

        if not external then
          // Notify cluster
          let msg = ChannelMsgEncoder.register_as_role(role, w_actor, _auth)
          _connections.send_control_to_cluster(msg)
        end

        ifdef "trace" then
          @printf[I32]("Registering WActor %s as role %s\n".cstring(),
            w_actor.string().cstring(), role.cstring())
        end
      end
    else
      Fail()
    end

  be tick() =>
    for a in _actors.values() do
      a.tick()
    end

  be distribute_data_router(r: RouterRegistry) =>
    let asr = ActiveActorSystemDataRouter(this)
    let data_router = DataRouter(where actor_system_router = asr)
    r.set_data_router(data_router)

  be broadcast(data: Any val, external: Bool = false) =>
    for target_id in _actors.keys() do
      _send_for_process(target_id, data)
    end

    if not external then
      try
        let msg = ChannelMsgEncoder.broadcast_to_actors(data, _auth)
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end
    end

  be broadcast_to_role(role: String, data: Any val) =>
    try
      for target_id in _role_sets(role).values() do
        _send_for_process(target_id, data)
      end
    else
      @printf[I32]("Trying to broadcast to nonexistent role %s!\n".cstring(),
        role.cstring())
    end

  be send_for_process(target_id: U128, data: Any val) =>
    _send_for_process(target_id, data)

  fun ref _send_for_process(target_id: U128, data: Any val) =>
    try
      let target_worker = _actor_to_worker_map(target_id)
      if target_worker == _worker_name then
        _actors(target_id).process(data)
      else
        let a_msg = ActorDeliveryMsg(_worker_name, target_id, data, None)
        _boundaries(target_worker).forward_actor_data(a_msg)
      end
    else
      Fail()
    end

  be send_to(target_id: U128, msg: WMessage val) =>
    _send_to(target_id, msg)

  fun ref _send_to(target_id: U128, msg: WMessage val) =>
    try
      let target_worker = _actor_to_worker_map(target_id)
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

  be process_by_role(role: String, data: Any val) =>
    try
      let target_id = _roles(role).next(_rand)
      _send_for_process(target_id, data)
    else
      @printf[I32]("Trying to send to nonexistent role!\n".cstring())
    end

  be send_to_role(role: String, sender: U128, data: Any val) =>
    try
      let target = _roles(role).next(_rand)
      let wrapped = WMessage(sender, target, data)
      send_to(target, wrapped)
    else
      Fail()
    end

  be process_digest(digest: WActorRegistryDigest) =>
    for (id, worker) in digest.actor_to_worker_map.pairs() do
      _register_actor_for_worker(id, worker)
    end
    for (role, ids) in digest.role_sets.pairs() do
      for id in ids.values() do
        _register_as_role(role, id)
      end
    end

  be send_digest(worker: String) =>
    let role_sets = recover trn Map[String, SetIs[U128]] end
    for (k, v) in _role_sets.pairs() do
      let next_set = recover SetIs[U128] end
      for id in v.values() do
        next_set.set(id)
      end
      role_sets(k) = consume next_set
    end
    let actor_to_worker_map = recover trn Map[U128, String] end
    for (k, v) in _actor_to_worker_map.pairs() do
      actor_to_worker_map(k) = v
    end
    let digest = WActorRegistryDigest(consume role_sets,
      consume actor_to_worker_map)
    try
      let msg = ChannelMsgEncoder.w_actor_registry_digest(digest, _auth)
      _connections.send_control(worker, msg)
    else
      Fail()
    end

class Role
  let _name: String
  let _actors: Array[U128] = _actors.create()

  new create(name': String) =>
    _name = name'

  fun name(): String =>
    _name

  fun empty(): Bool =>
    _actors.size() == 0

  fun actors(): Array[U128] box =>
    _actors

  fun ref local_actors(): Array[U128] =>
    _actors

  fun contains(w_actor: U128): Bool =>
    _actors.contains(w_actor)

  fun ref remove_actor(id: U128) ? =>
    let idx = _actors.find(id)
    _actors.remove(idx, 1)

  fun ref register_actor(w_actor: U128) =>
    if not _actors.contains(w_actor) then
      _actors.push(w_actor)
    end

  fun ref next(rand: EnhancedRandom): U128 ? =>
    rand.pick[U128](_actors)

  fun clone(): Role =>
    let new_role: Role trn = recover Role(_name) end
    for a in _actors.values() do
      new_role.register_actor(a)
    end
    consume new_role

class val WActorRegistryDigest
  let role_sets: Map[String, SetIs[U128]] val
  var actor_to_worker_map: Map[U128, String] val

  new val create(role_sets': Map[String, SetIs[U128]] val,
    actor_to_worker_map': Map[U128, String] val)
  =>
    role_sets = role_sets'
    actor_to_worker_map = actor_to_worker_map'
