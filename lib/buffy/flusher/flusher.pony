use "time"

interface FlushingActor
  be flush()

class FlushTimer is TimerNotify
"""
Use FlushTimer to invoke a periodic flush() behaviour on a target actor
"""
  let _target: FlushingActor tag

  new iso create(target: FlushingActor tag) =>
    _target = target

  fun ref apply(timer: Timer, count: U64): Bool =>
    _target.flush()
    true

primitive Flusher
  fun apply(target: FlushingActor tag, delay: U64 val) =>
    let timers = Timers
    let timer = Timer(FlushTimer(target), 0, delay)
    timers(consume timer)
