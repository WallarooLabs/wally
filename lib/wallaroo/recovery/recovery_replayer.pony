use "collections"
use "sendence/collection_helpers"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/topology"


actor RecoveryReplayer
  """
  Responsible for coordinating recovery replay protocol:

  1. After log replay is complete, we can begin the recovery replay process.
  2. Recovering worker contacts running workers to indicate it is preparing to
     accept replay messages.
  3. Runnings workers send a count of their boundaries to recovering worker.
  4. The recovering worker requests that incoming boundaries connect.
  4. When all expected boundaries are connected, the recovering worker
     requests replay from all incoming boundaries.
  4. Every incoming boundary replays its queue.
  5. After recovering worker receives a “replay complete” message from all
     distinct boundaries from every running worker (this can be inferred based
     on the boundary counts and the boundary id/worker name data in replay
     complete messages), the recovering worker informs the cluster that they
     can begin sending normal messages.
  6. Recovering worker is now also free to clear deduplication lists.

  ASSUMPTION: Recovery replay can happen at most once in the lifecycle of a
    worker.
  """
  let _worker_name: String
  let _auth: AmbientAuth
  var _replay_phase: _ReplayPhase = _EmptyReplayPhase
  // We keep track of all steps so we can tell them when to clear
  // their deduplication lists
  let _steps: SetIs[Step] = _steps.create()

  let _router_registry: RouterRegistry
  let _cluster: Cluster

  new create(auth: AmbientAuth, worker_name: String,
    router_registry: RouterRegistry, cluster: Cluster,
    is_recovering: Bool = false)
  =>
    _worker_name = worker_name
    _auth = auth
    _router_registry = router_registry
    _cluster = cluster
    if not is_recovering then
      _replay_phase = _NotRecoveryReplaying(this)
    end

  be register_step(step: Step) =>
    _steps.set(step)

  be add_expected_boundary_count(worker: String, count: USize) =>
    try
      _replay_phase.add_expected_boundary_count(worker, count)
    else
      Fail()
    end

  be add_reconnected_boundary(worker: String, boundary_id: U128) =>
    try
      _replay_phase.add_reconnected_boundary(worker, boundary_id)
    else
      Fail()
    end

  be add_boundary_replay_complete(worker: String, boundary_id: U128) =>
    try
      _replay_phase.add_boundary_replay_complete(worker, boundary_id)
    else
      Fail()
    end

  //////////////////////////
  // Managing Replay Phases
  //////////////////////////
  be start_recovery_replay(workers: Array[String] val) =>
    let expected_workers: SetIs[String] = expected_workers.create()
    for w in workers.values() do
      expected_workers.set(w)
    end
    if workers.size() != expected_workers.size() then Fail() end
    _replay_phase = _WaitingForBoundaryCounts(expected_workers, this)

    try
      let msg = ChannelMsgEncoder.request_boundary_count(_worker_name, _auth)
      _cluster.send_control_to_cluster(msg)
    else
      Fail()
    end

  fun ref _wait_for_reconnections(expected_boundaries: Map[String, USize] box,
    reconnected_boundaries: Map[String, SetIs[U128]])
  =>
    _replay_phase = _WaitForReconnections(expected_boundaries,
      reconnected_boundaries, this)
    try
      let msg = ChannelMsgEncoder.reconnect_data_port(_worker_name, _auth)
      _cluster.send_control_to_cluster(msg)
    else
      Fail()
    end

  fun ref _start_replay_phase(expected_boundaries: Map[String, USize] box) =>
    _replay_phase = _Replay(expected_boundaries, this)
    // Initializing data receivers will trigger replay over the boundaries
    _router_registry.initialize_data_receivers()

  fun ref _end_replay_phase() =>
    _replay_phase = _NotRecoveryReplaying(this)
    _clear_deduplication_lists()

  fun ref _clear_deduplication_lists() =>
    for s in _steps.values() do
      s.clear_deduplication_list()
    end

interface _RecoveryReplayer
  """
  This only exists for testability.
  """
  fun ref _wait_for_reconnections(expected_boundaries: Map[String, USize] box,
    reconnected_boundaries: Map[String, SetIs[U128]])
  fun ref _start_replay_phase(expected_boundaries: Map[String, USize] box)
  fun ref _end_replay_phase()
  fun ref _clear_deduplication_lists()

trait _ReplayPhase
  fun ref add_workers(workers: Array[String] val) ? =>
    error
  fun ref add_expected_boundary_count(worker: String, count: USize) ? =>
    error
  fun ref add_reconnected_boundary(worker: String, boundary_id: U128) ? =>
    error
  fun ref add_boundary_replay_complete(worker: String, boundary_id: U128) ? =>
    error

class _EmptyReplayPhase is _ReplayPhase

class _NotRecoveryReplaying is _ReplayPhase
  let _replayer: _RecoveryReplayer ref

  new create(replayer: _RecoveryReplayer ref) =>
    _replayer = replayer

  fun ref add_boundary_replay_complete(worker: String, boundary_id: U128) =>
    // If we experience a replay outside recovery, then we can immediately
    // clear deduplication lists when it's complete
    _replayer._clear_deduplication_lists()

class _WaitingForBoundaryCounts is _ReplayPhase
  let _expected_workers: SetIs[String]
  let _expected_boundaries: Map[String, USize] = _expected_boundaries.create()
  var _reconnected_boundaries: Map[String, SetIs[U128]] =
    _reconnected_boundaries.create()
  let _replayer: _RecoveryReplayer ref

  new create(expected_workers: SetIs[String],
    replayer: _RecoveryReplayer ref)
  =>
    _expected_workers = expected_workers
    _replayer = replayer

  fun ref add_expected_boundary_count(worker: String, count: USize) =>
    ifdef debug then
      // This should only be called once per worker
      Invariant(not _reconnected_boundaries.contains(worker))
    end
    _expected_boundaries(worker) = count
    _reconnected_boundaries(worker) = SetIs[U128]
    if SetHelpers[String].forall(_expected_workers,
      {(w: String)(_expected_boundaries): Bool =>
        _expected_boundaries.contains(w)})
    then
      _replayer._wait_for_reconnections(_expected_boundaries,
        _reconnected_boundaries)
    end

class _WaitForReconnections is _ReplayPhase
  let _expected_boundaries: Map[String, USize] box
  var _reconnected_boundaries: Map[String, SetIs[U128]]
  let _replayer: _RecoveryReplayer ref

  new create(expected_boundaries: Map[String, USize] box,
    reconnected_boundaries: Map[String, SetIs[U128]],
    replayer: _RecoveryReplayer ref)
  =>
    _expected_boundaries = expected_boundaries
    _reconnected_boundaries = reconnected_boundaries
    _replayer = replayer

  fun ref add_reconnected_boundary(worker: String, boundary_id: U128) ? =>
    _reconnected_boundaries(worker).set(boundary_id)
    if _all_boundaries_reconnected() then
      _replayer._start_replay_phase(_expected_boundaries)
    end

  fun _all_boundaries_reconnected(): Bool =>
    CheckCounts[String, U128](_expected_boundaries, _reconnected_boundaries)

class _Replay is _ReplayPhase
  let _expected_boundaries: Map[String, USize] box
  var _replay_completes: Map[String, SetIs[U128]] = _replay_completes.create()
  let _replayer: _RecoveryReplayer ref

  new create(expected_boundaries: Map[String, USize] box,
    replayer: _RecoveryReplayer ref)
  =>
    _expected_boundaries = expected_boundaries
    _replayer = replayer

  fun ref add_boundary_replay_complete(worker: String, boundary_id: U128) ? =>
    _replay_completes(worker).set(boundary_id)
    if _all_replays_complete(_replay_completes) then
      _replayer._end_replay_phase()
    end

  fun _all_replays_complete(replay_completes: Map[String, SetIs[U128]]):
    Bool
  =>
    CheckCounts[String, U128](_expected_boundaries, _replay_completes)

primitive CheckCounts[Key: (Hashable #read & Equatable[Key] #read),
  Counted]
  fun apply(expected_counts: Map[Key, USize] box,
    counted: Map[Key, SetIs[Counted]] box): Bool
  =>
    try
      for (key, count) in expected_counts.pairs() do
        ifdef debug then
          Invariant(counted(key).size() <= count)
        end
        if counted(key).size() < count then
          return false
        end
      end
      return true
    else
      Fail()
      return false
    end
