use "wallaroo/fail"
use "wallaroo/initialization"

actor Recovery
  """
  Phases:
    1) _NotRecovering: Waiting for start_recovery() to be called
    2) _LogReplay: Wait for EventLog to finish replaying the event logs
    3) _BoundaryMsgReplay: Wait for RecoveryReplayer to manage message replay
       from incoming boundaries.
    4) _NotRecovering: Finished recovery
  """
  let _worker_name: String
  var _recovery_phase: _RecoveryPhase = _NotRecovering
  var _workers: Array[String] val = recover Array[String] end

  let _event_log: EventLog
  let _recovery_replayer: RecoveryReplayer
  var _local_topology_initializer: (LocalTopologyInitializer | None) = None

  new create(worker_name: String, event_log: EventLog,
    recovery_replayer: RecoveryReplayer)
  =>
    _worker_name = worker_name
    _event_log = event_log
    _recovery_replayer = recovery_replayer

  be start_recovery(lti: LocalTopologyInitializer,
    workers: Array[String] val)
  =>
    let other_workers: Array[String] trn = recover Array[String] end
    for w in workers.values() do
      if w != _worker_name then other_workers.push(w) end
    end
    _workers = consume other_workers

    _local_topology_initializer = lti
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

  be recovery_replay_finished() =>
    try
      _recovery_phase.msg_replay_finished()
    else
      Fail()
    end

  fun ref _start_log_replay(workers: Array[String] val) =>
    @printf[I32]("|~~ - Recovery Phase A: Log Replay - ~~|\n".cstring())
    _recovery_phase = _LogReplay(workers, this)
    try
      _recovery_phase.start_log_replay(_event_log)
    else
      Fail()
    end

  fun ref _start_msg_replay(workers: Array[String] val) =>
    @printf[I32]("|~~ - Recovery Phase B: Recovery Message Replay - ~~|^^\n"
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
    match _local_topology_initializer
    | let lti: LocalTopologyInitializer =>
      _event_log.start_logging(lti)
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
  fun start_msg_replay() ? =>
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
    _recovery._start_msg_replay(_workers)

class _BoundaryMsgReplay is _RecoveryPhase
  let _workers: Array[String] val
  let _recovery_replayer: RecoveryReplayer
  let _recovery: Recovery ref

  new create(workers: Array[String] val, recovery_replayer: RecoveryReplayer,
    recovery: Recovery ref)
  =>
    _workers = workers
    _recovery_replayer = recovery_replayer
    _recovery = recovery

  fun start_msg_replay() =>
    _recovery_replayer.start_recovery_replay(_workers, _recovery)

  fun ref msg_replay_finished() =>
    _recovery._end_recovery()
