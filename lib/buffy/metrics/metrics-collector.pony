use "collections"
use "net"
use "buffy/messages"
use "buffy/epoch"
use "buffy/flusher"

actor MetricsCollector is FlushingActor
  let _stderr: StdStream
  let _auth: AmbientAuth
  let _node_name: String
  var _step_summary: NodeMetricsSummary trn
  var _boundary_summary: BoundaryMetricsSummary trn
  let _conn: (TCPConnection | None)
  let _max_batch: USize
  let _max_time: U64
  var _node_last_sent: U64 = Epoch.nanoseconds()
  var _boundary_last_sent: U64 = Epoch.nanoseconds()
  var _largest_boundary_summary_size: USize = 0
  var _largest_step_summary_size: USize = 0

	new create(stderr: StdStream, auth: AmbientAuth, node_name: String,
             conn: (TCPConnection | None) = None, max_batch: USize = 10000,
             max_time: U64 = 1_000_000_000) =>
    _stderr = stderr
	  _auth = auth
    _node_name = node_name
	  _conn = conn
    _max_batch = max_batch
    _max_time = max_time
    _boundary_summary = recover BoundaryMetricsSummary(node_name) end
    _step_summary = recover NodeMetricsSummary(node_name) end

  be flush() =>
    if _step_summary.size() > 0 then _send_steps() end
    if _boundary_summary.size() > 0 then _send_boundary() end

	be report_step_metrics(step_id: StepId, start_time: U64, end_time: U64) =>
    let r = StepMetricsReport(start_time, end_time)
    _step_summary.add_report(consume step_id, consume r)
    _send_steps_if_over_max()

  be flush_step_metrics() =>
    _send_steps_if_over_max()

  fun ref _send_steps_if_over_max() =>
	  if (_step_summary.size() > _max_batch) or
       ((Epoch.nanoseconds() - _node_last_sent) > _max_time)
    then
      _send_steps()
	  end

  fun ref _send_steps() =>
      let node_name: String val = _node_name.clone()
      var size = _step_summary.size()
      if size > _largest_step_summary_size then 
        _largest_step_summary_size = size
      else
        size = _largest_step_summary_size
      end       
      let summary = _step_summary =
        recover 
          trn NodeMetricsSummary(node_name, size) 
        end
      let s:NodeMetricsSummary val = consume summary
      _send_step_metrics_to_receiver(s)
      _node_last_sent = Epoch.nanoseconds()

  fun ref _send_step_metrics_to_receiver(summary: NodeMetricsSummary val) =>
    match _conn
    | let c: TCPConnection =>
      try
        let encoded = MetricsMsgEncoder.nodemetrics(summary, _auth)
        c.writev(encoded)
      else
        _stderr.print("Failed to send NodeMetricsSummary.")
      end
    end

	be report_boundary_metrics(boundary_type: U64, msg_id: U64, start_time: U64,
		end_time: U64) =>
		_boundary_summary.add_report(BoundaryMetricsReport(boundary_type,
			msg_id, start_time, end_time))
    _send_boundary_if_over_max()

  be flush_boundary_metrics() =>
    _send_boundary_if_over_max()

  fun ref _send_boundary_if_over_max() =>
	  if (_boundary_summary.size() > _max_batch) or
       ((Epoch.nanoseconds() - _boundary_last_sent) > _max_time)
    then
      _send_boundary()
	  end

  fun ref _send_boundary() =>
      let node_name: String val = _node_name.clone()
      var size = _boundary_summary.size()
      if size > _largest_boundary_summary_size then 
        _largest_boundary_summary_size = size
      else
        size = _largest_boundary_summary_size
      end
	    let summary = _boundary_summary =
        recover trn BoundaryMetricsSummary(node_name, size) end
      let s: BoundaryMetricsSummary val = consume summary
	    _send_boundary_metrics_to_receiver(s)
      _boundary_last_sent = Epoch.nanoseconds()

  fun ref _send_boundary_metrics_to_receiver(
    summary: BoundaryMetricsSummary val) =>
  	match _conn
  	| let c: TCPConnection =>
      try
        let encoded = MetricsMsgEncoder.boundarymetrics(summary, _auth)
        c.writev(encoded)
      else
        _stderr.print("Failed to send BoundaryMetricsSummary.")
      end
		end

class StepReporter
	let _step_id: U64
	let _metrics_collector: MetricsCollector

	new val create(s_id: U64, m_coll: MetricsCollector) =>
		_step_id = s_id
		_metrics_collector = m_coll

	fun report(start_time: U64, end_time: U64) =>
		_metrics_collector.report_step_metrics(_step_id, start_time, end_time)
