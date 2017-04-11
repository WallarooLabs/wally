use "wallaroo/resilience"

actor Recovery
  var _recovery_phase: _RecoveryPhase = _NotRecovering

  let _alfred: Alfred

  new create(alfred: Alfred) =>
    _alfred = alfred

  be start_recovery() =>
    _recovery_phase = _LogReplay
    // _alfred.start_log_replay()

trait _RecoveryPhase

class _NotRecovering is _RecoveryPhase

class _LogReplay is _RecoveryPhase
