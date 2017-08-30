use "wallaroo/ent/network"
use "wallaroo/ent/w_actor"
use "wallaroo/fail"
use "wallaroo/initialization"
use "wallaroo/messages"

actor Recovery
  """
  Phases:
    1) _NotRecovering: Waiting for start_recovery() to be called
    2) _LogReplay: Wait for EventLog to finish replaying the event logs
    3) _WActorRegistryRecovery: For ActorSystem, wait to receive
       WActorRegistryDigest. For Pipeline, skip this phase.
    4) _BoundaryMsgReplay: Wait for RecoveryReplayer to manage message replay
       from incoming boundaries.
    5) _NotRecovering: Finished recovery
  """
  let _auth: AmbientAuth
  let _worker_name: String
  var _recovery_phase: _RecoveryPhase = _NotRecovering
  var _workers: Array[String] val = recover Array[String] end

  let _event_log: EventLog
  let _recovery_replayer: (RecoveryReplayer | None)
  let _connections: Connections
  var _initializer: (LocalTopologyInitializer | WActorInitializer | None) =
    None

  new create(auth: AmbientAuth, worker_name: String, event_log: EventLog,
    recovery_replayer: (RecoveryReplayer | None) = None,
    connections: Connections)
  =>
    _auth = auth
    _worker_name = worker_name
    _event_log = event_log
    _recovery_replayer = recovery_replayer
    _connections = connections

  be start_recovery(
    initializer: (LocalTopologyInitializer | WActorInitializer),
    workers: Array[String] val)
  =>
    let other_workers = recover trn Array[String] end
    for w in workers.values() do
      if w != _worker_name then other_workers.push(w) end
    end
    _workers = consume other_workers

    _initializer = initializer
    try
      _recovery_phase.start_recovery(workers, this)
    else
      Fail()
    end

  be log_replay_finished() =>
    try
      _recovery_phase.log_replay_finished()
    else
      Fail()
    end

  be w_actor_registry_recovery_finished() =>
    try
      _recovery_phase.w_actor_registry_recovery_finished()
    else
      Fail()
    end

  be recovery_replay_finished() =>
    try
      _recovery_phase.msg_replay_finished()
    else
      Fail()
    end

  fun ref _start_log_replay(workers: Array[String] val) =>
    ifdef "resilience" then
      @printf[I32]("|~~ - Recovery Phase: Log Replay - ~~|\n".cstring())
    end
    _recovery_phase = _LogReplay(workers, this)
    try
      _recovery_phase.start_log_replay(_event_log)
    else
      Fail()
    end

  fun ref _end_log_replay(workers: Array[String] val) =>
    match _initializer
    | let lti: LocalTopologyInitializer =>
      _start_msg_replay(workers)
    | let wai: WActorInitializer =>
      _start_w_actor_registry_recovery(workers)
      wai.start_app()
    else
      Fail()
    end

  fun ref _start_w_actor_registry_recovery(workers: Array[String] val) =>
    @printf[I32]("|~~ - Recovery Phase: WActor Registry Recovery - ~~|\n"
      .cstring())
    _recovery_phase = _WActorRegistryRecovery(_worker_name, workers, this,
      _auth, _connections)
    try
      _recovery_phase.start_w_actor_registry_recovery()
    else
      Fail()
    end

  fun ref _end_w_actor_registry_recovery(workers: Array[String] val) =>
    _start_msg_replay(workers)

  fun ref _start_msg_replay(workers: Array[String] val) =>
    @printf[I32]("|~~ - Recovery Phase: Recovery Message Replay - ~~|\n"
      .cstring())
    _recovery_phase = _BoundaryMsgReplay(workers, _recovery_replayer, this)
    try
      _recovery_phase.start_msg_replay()
    else
      Fail()
    end

  fun ref _end_recovery() =>
    @printf[I32]("|~~ - Recovery COMPLETE - ~~|\n".cstring())
    _recovery_phase = _NotRecovering
    match _initializer
    | let lti: LocalTopologyInitializer =>
      _event_log.start_pipeline_logging(lti)
    | let wai: WActorInitializer =>
      _event_log.start_actor_system_logging(wai)
    else
      Fail()
    end

trait _RecoveryPhase
  fun start_recovery(workers: Array[String] val, recovery: Recovery ref) ? =>
    error
  fun start_log_replay(event_log: EventLog) ? =>
    error
  fun ref log_replay_finished() ? =>
    error
  fun ref start_w_actor_registry_recovery() ? =>
    error
  fun ref w_actor_registry_recovery_finished() ? =>
    error
  fun ref start_msg_replay() ? =>
    error
  fun ref msg_replay_finished() ? =>
    error

class _NotRecovering is _RecoveryPhase
  fun start_recovery(workers: Array[String] val, recovery: Recovery ref) =>
    recovery._start_log_replay(workers)

class _LogReplay is _RecoveryPhase
  let _workers: Array[String] val
  let _recovery: Recovery ref

  new create(workers: Array[String] val, recovery: Recovery ref) =>
    _workers = workers
    _recovery = recovery

  fun start_log_replay(event_log: EventLog) =>
    event_log.start_log_replay(_recovery)

  fun ref log_replay_finished() =>
    _recovery._end_log_replay(_workers)

class _WActorRegistryRecovery is _RecoveryPhase
  let _auth: AmbientAuth
  let _worker_name: String
  let _workers: Array[String] val
  let _recovery: Recovery ref
  let _connections: Connections

  new create(name: String, workers: Array[String] val, recovery: Recovery ref,
    auth: AmbientAuth, connections: Connections)
  =>
    _auth = auth
    _worker_name = name
    _workers = workers
    _recovery = recovery
    _connections = connections

  fun ref start_w_actor_registry_recovery() =>
    try
      let msg = ChannelMsgEncoder.request_w_actor_registry_digest(_worker_name,
        _auth)
      _connections.send_control_to_random(msg)
    else
      Fail()
    end

  fun ref w_actor_registry_recovery_finished() =>
    _recovery._end_w_actor_registry_recovery(_workers)

class _BoundaryMsgReplay is _RecoveryPhase
  let _workers: Array[String] val
  let _recovery_replayer: (RecoveryReplayer | None)
  let _recovery: Recovery ref

  new create(workers: Array[String] val,
    recovery_replayer: (RecoveryReplayer | None), recovery: Recovery ref)
  =>
    _workers = workers
    _recovery_replayer = recovery_replayer
    _recovery = recovery

  fun ref start_msg_replay() =>
    match _recovery_replayer
    | let rr: RecoveryReplayer =>
      rr.start_recovery_replay(_workers, _recovery)
    else
      @printf[I32]("|~~ - - No RecoveryReplayer: Finishing early - - ~~|\n".cstring())
      msg_replay_finished()
    end

  fun ref msg_replay_finished() =>
    _recovery._end_recovery()
