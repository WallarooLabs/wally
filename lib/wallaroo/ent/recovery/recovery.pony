/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/ent/network"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"

actor Recovery
  """
  Phases:
    1) _NotRecovering: Waiting for start_recovery() to be called
    2) _LogReplay: Wait for EventLog to finish replaying the event logs
    3) _BoundaryMsgReplay: Wait for RecoveryReplayer to manage message replay
       from incoming boundaries.
    4) _NotRecovering: Finished recovery
  """
  let _auth: AmbientAuth
  let _worker_name: String
  var _recovery_phase: _RecoveryPhase = _NotRecovering
  var _workers: Array[String] val = recover Array[String] end

  let _event_log: EventLog
  let _recovery_replayer: (RecoveryReplayer | None)
  let _connections: Connections
  var _initializer: (LocalTopologyInitializer | None) =
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
    initializer: LocalTopologyInitializer,
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
    else
      Fail()
    end

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
      @printf[I32]("|~~ - - No RecoveryReplayer: Finishing early - - ~~|\n"
        .cstring())
      msg_replay_finished()
    end

  fun ref msg_replay_finished() =>
    _recovery._end_recovery()
