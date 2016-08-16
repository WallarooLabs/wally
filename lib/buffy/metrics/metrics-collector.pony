use "collections"
use "net"
use "json"
use "buffy/messages"
use "buffy/flusher"
use "sendence/epoch"
use "sendence/hub"

actor JsonAccumulator
  let _output: (MetricsOutputActor tag | None)
  let _file_output: (MetricsOutputActor tag | None)
  let _event: String
  let _topic: String
  let _pretty_print: Bool
  var j: JsonArray ref = JsonArray(100)
  var _size: USize = 0

  new create(event: String, topic: String, pretty_print: Bool=false,
    output: (MetricsOutputActor tag | None),
    file_output: (MetricsOutputActor tag | None))
  =>
    _output = output
    _file_output = file_output
    _event = event
    _topic = topic
    _pretty_print = pretty_print

  be append(j': JsonArray iso) =>
    let j'': JsonArray ref = consume j'
    if j''.data.size() > 0 then
      j.data.concat(j''.data.values())
      _size = j.data.size()
    end

  be flush() =>
    if _size > 0 then
      let j': JsonArray ref = j = JsonArray(100)
      _size = 0
      if (_output isnt None) or (_file_output isnt None) then
        let s: ByteSeq val = HubJson.payload(_event, _topic, consume j',
          _pretty_print)
        match _output
        | let o: MetricsOutputActor tag => o(s)
        end
        match _file_output
        | let o: MetricsOutputActor tag => o(s)
        end
      end
    end

actor TimelineCollector
"""
An actor responsible for collecting Timelines from a single step, node, or
sink's MetricsRecorder
"""
  var timelines: Array[Timeline iso] iso = recover
    Array[Timeline iso](10) end
  let _show_empty: Bool

  new create(show_empty: Bool=false) =>
    _show_empty = show_empty

  be apply(t: Timeline iso) =>
  """
  Add a new Timeline to the local collection
  """
    timelines.push(consume t)

  be flush(collectors: Array[TimelineCollector tag] iso,
    output: JsonAccumulator tag)
  =>
    let t: Array[Timeline iso] iso = timelines = recover Array[Timeline iso](10) end
    while t.size() > 0 do
      try
        let json: (JsonArray iso | None) = recover
          let tl: Timeline ref = t.pop()
          if tl.size() > 0 then
            tl.json(_show_empty)
          else
            None
          end
        end
        match consume json
        | let j: JsonArray iso => output.append(consume j)
        end
      end
    end
    try
      let tlc:TimelineCollector tag = collectors.pop()
      tlc.flush(consume collectors, output)
    else
      output.flush()
    end

actor MetricsCollector is FlushingActor
  let _stdout: StdStream
  let _stderr: StdStream
  let _auth: AmbientAuth
  let _node_name: String val
  let _app_name: String val
  let _timelines: Array[TimelineCollector tag] ref = recover
    Array[TimelineCollector tag](50) end
  let _event: String val
  let _topic: String val
  let _pretty_print: Bool val = false
  var _output: (MetricsOutputActor tag | None) = None
  var _file_output: (MetricsOutputActor tag | None) = None

  new create(stdout: StdStream,
    stderr: StdStream,
    auth: AmbientAuth,
    node_name: String,
    app_name: String,
    metrics_host: (String | None) = None,
    metrics_service: (String | None) = None,
    report_file: (String | None) = None,
    period: U64 = 1_000_000_000,
    flush_period: U64 = 1_000_000_000)
  =>
    _stdout = stdout
    _stderr = stderr
	  _auth = auth
    _node_name = node_name
    _app_name = app_name
    _event = "metrics"
    _topic = recover
      let s: String ref = String(50)
      s.append("metrics:")
      s.append(app_name)
      consume s
    end

    // Create connections and actors here

    // MonitoringHub Output:
    match (metrics_host, metrics_service)
    | (let host: String, let service: String) =>
      let notifier: TCPConnectionNotify iso =
        recover MonitoringHubConnectNotify(stdout, stderr) end
      let conn' = TCPConnection(auth, consume notifier, host, service)
      _output = MonitoringHubOutput(stdout, stderr, conn', app_name)
    end

    // File output
    match report_file
    | let arg: String =>
      _file_output = MetricsFileOutput(stdout, stderr, auth, app_name, arg)
    end

  be finished() =>
    _flush()

  be flush() => _flush()

  fun _flush() =>
    // TODO: Rerwite this so we don't have to copy the _timelines array
    // and use promises and a known count at the accumulator instead.
    // TODO: Add backoff to the flushing timer
    let j: JsonAccumulator tag = recover JsonAccumulator(_event, _topic,
      _pretty_print, _output, _file_output) end
    let size: USize val = _timelines.size()
    var col: Array[TimelineCollector tag] iso = recover
      Array[TimelineCollector tag](size) end
    for tc in _timelines.values() do
      col.push(tc)
    end
    try
      let tlc: TimelineCollector tag = col.pop()
      tlc.flush(consume col, j)
    end

  be add_collector(t: TimelineCollector tag) =>
  """
  Save a tag to TimelineCollector to the local collection
  """
    _timelines.push(t)

class MetricsReporter
	let _id: U64
  let _name: String
  let _category: String
  let _period: U64
  let _timelinecollector: TimelineCollector tag
  var _timeline: Timeline iso

	new iso create(id: U64, name: String, category: String,
    metrics_collector: (MetricsCollector tag | None),
    period: U64=1_000_000_000)
  =>
    _id = id
    _name = name
    _category = category
    _period = period
    _timelinecollector = TimelineCollector
    _timeline = recover Timeline(_id, _name, _category, _period) end
    match metrics_collector
    | let m: MetricsCollector tag =>
      m.add_collector(_timelinecollector)
    end

  fun ref report(dt: U64, end_time: (U64 | None)=None) =>
    apply(dt, end_time)

	fun ref apply(dt: U64, end_time: (U64 | None)=None) =>
    _timeline(dt, end_time)
    if _timeline.size() > 1 then flush() end

  fun ref flush() =>
  """
  Flush the current Timeline to the TimelineCollector
  """
    if _timeline.size() > 0 then
      let t = _timeline = recover Timeline(_id, _name, _category, _period) end
      _timelinecollector(consume t)
    end

