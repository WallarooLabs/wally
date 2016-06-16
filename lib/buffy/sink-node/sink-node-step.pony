use "../topology"
use "buffy/messages"
use "time"

trait StringInStep
  be apply(input: String)

actor SinkNodeStep[Diff: Any #read] 
  is StringInStep
  let _collector: SinkCollector[Diff]
  let _stringify: Stringify[Diff] val
  var _output: SinkConnection
  let _timers: Timers = Timers

  new create(collector_builder: {(): SinkCollector[Diff]} val, 
    stringify: Stringify[Diff] val,
    output: SinkConnection) =>
    _collector = collector_builder()
    _stringify = stringify
    _output = output
    let t = Timer(_SendDiff[Diff](this), 1_000_000_000, 1_000_000_000)
    _timers(consume t)

  be apply(input: String) =>
    _collector(input)

  be send_diff() =>
    if _collector.has_diff() then
      try
        let stringified = _stringify(_collector.diff())
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
