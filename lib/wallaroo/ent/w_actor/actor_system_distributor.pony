use "collections"
use "files"
use "net"
use "sendence/dag"
use "sendence/guid"
use "sendence/messages"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/ent/network"
use "wallaroo/topology"
use "wallaroo/recovery"

actor ActorSystemDistributor is Distributor
  let _auth: AmbientAuth
  let _guid_gen: GuidGenerator = GuidGenerator
  let _w_actor_initializer: WActorInitializer
  let _connections: Connections
  let _input_addrs: Array[Array[String]] val
  var _system: ActorSystem val
  let _is_recovering: Bool

  new create(auth: AmbientAuth, actor_system: ActorSystem val,
    w_actor_initializer: WActorInitializer, connections: Connections,
    input_addrs: Array[Array[String]] val, is_recovering: Bool)
  =>
    _auth = auth
    _system = actor_system
    _w_actor_initializer = w_actor_initializer
    _connections = connections
    _input_addrs = input_addrs
    _is_recovering = is_recovering

  be topology_ready() =>
    None

  be distribute(cluster_initializer: (ClusterInitializer | None),
    worker_count: USize, workers: Array[String] val,
    initializer_name: String)
  =>
    try
      /*
      Try to evenly distribute the actors across the workers. As long as
      worker_count >= actor_count, then every worker gets at least
      (worker_count / actor_count) actors. The last worker also gets the
      remaining actors after all those have been distributed.
      */
      let actor_to_worker_map = recover trn Map[U128, String] end
      let actor_builders = _system.actor_builders()
      let actor_count = actor_builders.size()
      let base_share = actor_count / worker_count
      let shares: Array[Array[WActorWrapperBuilder] val] = shares.create()
      var actor_idx: USize = 0
      var worker_idx: USize = 0
      var cur_worker_share: USize = 0
      var cur_actors = recover trn Array[WActorWrapperBuilder] end
      while actor_idx < actor_count do
        let next_actor = actor_builders(actor_idx)
        actor_to_worker_map(next_actor.id()) = workers(worker_idx)
        cur_actors.push(next_actor)
        actor_idx = actor_idx + 1
        cur_worker_share = cur_worker_share + 1
        if actor_idx == actor_count then
          shares.push(cur_actors = recover Array[WActorWrapperBuilder] end)
        elseif cur_worker_share == base_share then
          // If this worker is the last one, then we won't get to this
          // check again and all the remaining actors will be placed on it.
          // The last worker will potentially have a few more actors than
          // the others given this algorithm.
          if worker_idx < (worker_count - 1) then
            worker_idx = worker_idx + 1
            cur_worker_share = 0
            shares.push(cur_actors = recover Array[WActorWrapperBuilder] end)
          end
        end
      end
      if worker_idx < (worker_count - 1) then
        while worker_idx < worker_count do
          shares.push(recover Array[WActorWrapperBuilder] end)
          worker_idx = worker_idx + 1
        end
      end
      let sendable_actor_to_worker_map: Map[U128, String] val =
        consume actor_to_worker_map

      // Create local actor systems for all other workers
      for w_idx in Range(1, worker_count) do
        let worker_name = workers(w_idx)
        let ls = LocalActorSystem(_system.name(), shares(w_idx),
          _system.sources(), _system.sinks(), sendable_actor_to_worker_map,
          workers, recover Map[String, Role box] end,
          _system.broadcast_variables())
        let msg = ChannelMsgEncoder.spin_up_local_actor_system(ls, _auth)
        _connections.send_control(worker_name, msg)
      end

      // Create our local system and initialize
      let local_system = LocalActorSystem(_system.name(), shares(0),
        _system.sources(), _system.sinks(), sendable_actor_to_worker_map,
        workers, recover Map[String, Role box] end,
        _system.broadcast_variables())
      _w_actor_initializer.update_local_actor_system(local_system)
      _w_actor_initializer.update_actor_to_worker_map(
        sendable_actor_to_worker_map)
      _w_actor_initializer.initialize(cluster_initializer, _is_recovering)
    else
      Fail()
    end
