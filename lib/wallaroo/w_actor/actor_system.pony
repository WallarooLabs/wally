use "collections"
use "net"
use "time"
use "sendence/guid"
use "wallaroo/fail"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/tcp_sink"
use "wallaroo/tcp_source"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/topology"

primitive Act
primitive Finish

class ActorSystem
  let _name: String
  let _seed: U64
  let _guid: GuidGenerator
  let _actor_builders: Array[WActorWrapperBuilder] = _actor_builders.create()
  let _sources: Array[(WActorFramedSourceHandler, WActorRouter)] =
    _sources.create()
  let _sinks: Array[TCPSinkBuilder] = _sinks.create()

  new create(name': String, seed': U64 = Time.micros()) =>
    _name = name'
    _seed = seed'
    _guid = GuidGenerator(_seed)

  fun name(): String => _name
  fun seed(): U64 => _seed

  fun ref add_actor(builder: WActorBuilder) =>
    let next = StatefulWActorWrapperBuilder(_guid.u128(), builder)
    _actor_builders.push(next)

  fun ref add_actors(builders: Array[WActorBuilder]) =>
    for b in builders.values() do
      add_actor(b)
    end

  fun ref add_source(handler: WActorFramedSourceHandler,
    actor_router: WActorRouter)
  =>
    _sources.push((handler, actor_router))

  // TODO: Figure out why this failed to get passed "Reachability"
  // when compiling if you use .> but not if you use .
  fun ref add_sink[Out: Any val](encoder: SinkEncoder[Out],
    initial_msgs: Array[Array[ByteSeq] val] val
      = recover Array[Array[ByteSeq] val] end): ActorSystem
  =>
    let builder = TCPSinkBuilder(TypedEncoderWrapper[Out](encoder),
      initial_msgs)
    _sinks.push(builder)
    this

  fun val actor_builders(): Array[WActorWrapperBuilder] val =>
    _actor_builders

  fun val sources(): Array[(WActorFramedSourceHandler, WActorRouter)] val =>
    _sources

  fun val sinks(): Array[TCPSinkBuilder] val =>
    _sinks

class val LocalActorSystem
  let _name: String
  let _actor_builders: Array[WActorWrapperBuilder] val
  let _sources: Array[(WActorFramedSourceHandler, WActorRouter)] val
  let _sinks: Array[TCPSinkBuilder] val
  let _actor_to_worker_map: Map[U128, String] val
  let _worker_names: Array[String] val
  let _roles: Map[String, Role box] val

  new val create(name': String,
    actor_builders': Array[WActorWrapperBuilder] val,
    sources': Array[(WActorFramedSourceHandler, WActorRouter)] val,
    sinks': Array[TCPSinkBuilder] val,
    actor_to_worker_map': Map[U128, String] val,
    worker_names': Array[String] val,
    roles': Map[String, Role box] val)
  =>
    _name = name'
    _actor_builders = actor_builders'
    _sources = sources'
    _sinks = sinks'
    _actor_to_worker_map = actor_to_worker_map'
    _worker_names = worker_names'
    _roles = roles'

  fun name(): String => _name

  fun add_actor(builder: WActorWrapperBuilder, worker: String):
    LocalActorSystem
  =>
    //TODO: Use persistent vector once it's available to improve perf here
    let arr: Array[WActorWrapperBuilder] trn =
      recover Array[WActorWrapperBuilder] end
    for a in _actor_builders.values() do
      arr.push(a)
    end
    arr.push(builder)
    //TODO: Use persistent map here to improve perf
    let new_actor_to_worker: Map[U128, String] trn =
      recover Map[U128, String] end
    for (k, v) in _actor_to_worker_map.pairs() do
      new_actor_to_worker(k) = v
    end
    new_actor_to_worker(builder.id()) = worker
    LocalActorSystem(_name, consume arr, _sources, _sinks,
      consume new_actor_to_worker, _worker_names, _roles)

  fun register_as_role(role: String, id: U128): LocalActorSystem =>
    //TODO: Use persistent map to improve perf
    let new_roles: Map[String, Role box] trn =
      recover Map[String, Role box] end
    for (k, v) in _roles.pairs() do
      if k == role then
        let old_role_actors = v.actors()
        let new_role: Role trn = recover Role(role) end
        for a in old_role_actors.values() do
          new_role.register_actor(a)
        end
        new_role.register_actor(id)
        new_roles(k) = consume new_role
      else
        new_roles(k) = v
      end
    end
    LocalActorSystem(_name, _actor_builders, _sources, _sinks,
      _actor_to_worker_map, _worker_names, consume new_roles)

  fun register_roles_in_registry(cr: CentralWActorRegistry) =>
    for (n, role) in _roles.pairs() do
      for id in role.actors().values() do
        cr.register_as_role(n, id)
      end
    end

  fun actor_builders(): Array[WActorWrapperBuilder] val =>
    _actor_builders

  fun sources(): Array[(WActorFramedSourceHandler, WActorRouter)] val =>
    _sources

  fun sinks(): Array[TCPSinkBuilder] val =>
    _sinks

  fun actor_to_worker_map(): Map[U128, String] val =>
    _actor_to_worker_map

  fun worker_names(): Array[String] val =>
    _worker_names

  fun roles(): Map[String, Role box] val =>
    _roles
