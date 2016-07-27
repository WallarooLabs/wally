use "collections"
use "net"
use "buffy/messages"
use "buffy/epoch"
use "buffy/flusher"

actor MetricsCollector is FlushingActor
  let _stdout: StdStream
  let _stderr: StdStream
  let _auth: AmbientAuth
  let _node_name: String
  let _collections: Array[MetricsCollection tag] ref = recover
    Array[MetricsCollection tag] end

  new create(stdout: StdStream,
    stderr: StdStream,
    auth: AmbientAuth,
    node_name: String,
    app_name: String,
    metrics_host: (String | None) = None,
    metrics_service: (String | None) = None,
    report_file: (String | None) = None,
    period: U64 = 1_000_000_000,
    report_period: U64 = 300_000_000_000)
  =>
    _stdout = stdout
    _stderr = stderr
	  _auth = auth
    _node_name = node_name

    // Create connections and actors here

    // MonitoringHub Output:
    match (metrics_host, metrics_service)
    | (let host: String, let service: String) =>
      let notifier: TCPConnectionNotify iso =
        recover MonitoringHubConnectNotify(stdout, stderr) end
      let conn' = TCPConnection(auth, consume notifier, host, service)
      let output = MonitoringHubOutput(stdout, stderr, conn', app_name)
      let handler: MetricsOutputHandler val =
        MetricsOutputHandler(MonitoringHubEncoder, consume output, app_name)

      // Metrics Collection actor
      let bin_selector: F64Selector val = Log10Selector //FixedBinSelector
      let mc = MetricsCollection(bin_selector, period, handler)

      // start a timer to flush the metrics-collection
      Flusher(mc, period)

      _collections.push(consume mc)
    end

    // File Output
    match report_file
    | let arg: String =>
      let output' = MetricsFileOutput(stdout, stderr, auth, app_name,
        arg)
      let handler': MetricsOutputHandler val =
        MetricsOutputHandler(MonitoringHubEncoder(false), consume output',
          app_name)
      let bin_selector': F64Selector val = FixedBinSelector
      let mc' = MetricsCollection(bin_selector', report_period, handler')

      // start a timer to flush the metrics-collection
      Flusher(mc', report_period)

      _collections.push(consume mc')
      stdout.print(recover val
        let out': String ref = String(100)
        out'.append("reporting to file ")
        out'.append(arg)
        out'.append(" every ")
        out'.append((report_period/1_000_000_000).string())
        out'.append(" seconds.")
        consume out' end)
    end

  be finished() =>
    _flush()

  be flush() => _flush()

  fun _flush() =>
    for mc in _collections.values() do
      mc.send_output()
    end

	be report_step_metrics(step_id: StepId, step_name: String, start_time: U64,
    end_time: U64) =>
    for mc in _collections.values() do
      mc.process_step(step_name, start_time, end_time)
    end

	be report_boundary_metrics(boundary_type: U64, msg_id: U64, start_time: U64,
    end_time: U64, pipeline_name: String = "") =>
    for mc in _collections.values() do
      if boundary_type == 0 then
        mc.process_sink(pipeline_name, start_time, end_time)
      elseif boundary_type == 1 then
        mc.process_boundary(pipeline_name, start_time, end_time)
      end
    end


class StepReporter
	let _step_id: U64
  let _step_name: String
	let _metrics_collector: MetricsCollector

	new val create(s_id: U64, s_name: String, m_coll: MetricsCollector) =>
		_step_id = s_id
    _step_name = s_name
		_metrics_collector = m_coll

	fun report(start_time: U64, end_time: U64) =>
		_metrics_collector.report_step_metrics(_step_id, _step_name, start_time,
      end_time)
