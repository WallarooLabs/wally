use "../topology"
use "buffy/messages"
use "time"

trait StringInStep
  be apply(input: Array[String] val)

actor SinkNodeStep[Diff: Any #read] 
  is StringInStep
  let _collector: SimpleSinkCollector[Diff]
  let _array_stringify: ArrayStringify[Diff] val
  var _output: SinkConnection
  let _timers: Timers = Timers

  new create(collector_builder: {(): SimpleSinkCollector[Diff]} val, 
    array_stringify: ArrayStringify[Diff] val,
    output: SinkConnection) =>
    _collector = collector_builder()
    _array_stringify = array_stringify
    _output = output
    let t = Timer(_SendDiff[Diff](this), 1_000_000_000, 1_000_000_000)
    _timers(consume t)

  be apply(input: Array[String] val) =>
    _collector(input)

  be send_diff() =>
    if _collector.has_diff() then
      try
        let stringified = _array_stringify(_collector.diff())
        _output(stringified)
        _collector.clear_diff()
      end
    end

class _SendDiff[Diff: Any #read] is TimerNotify
  let _step: SinkNodeStep[Diff] tag

  new iso create(step: SinkNodeStep[Diff] tag) =>
    _step = step

  fun ref apply(timer: Timer, count: U64): Bool =>
    _step.send_diff()
    true 
