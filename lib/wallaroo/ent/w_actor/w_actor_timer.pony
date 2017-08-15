use "collections"

class WActorTimers
  let _timers: Set[WActorTimer] = _timers.create()

  fun ref set_timer(t: WActorTimer) =>
    _timers.set(t)

  fun ref cancel_timer(t: WActorTimer) =>
    _timers.unset(t)

  fun ref tick() =>
    for t in _timers.values() do
      let expired = t.tick()
      if expired then _timers.unset(t) end
    end

class WActorTimer is Equatable[WActorTimer]
  """
  Set timers in seconds
  """
  let _duration: U128
  var _tick: U128 = 0
  let _callback: {()}
  let _is_repeating: Bool

  new create(duration: U128, callback: {()}, is_repeating: Bool = false) =>
    _duration = duration
    _callback = callback
    _is_repeating = is_repeating

  fun ref tick(): Bool =>
    """
    Return true to indicate the timer has expired
    """
    _tick = _tick + 1
    if _tick >= _duration then
      _callback()
      if _is_repeating then
        _tick = 0
        false
      else
        true
      end
    else
      false
    end

  fun eq(that: box->WActorTimer): Bool =>
    this is that

  fun hash(): U64 =>
    (digestof this).hash()
