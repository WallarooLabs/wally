use "collections"
use "net"
use "buffy/messages"
use "sendence/bytes"
use "sendence/epoch"

actor MetricsCollector
  let _auth: AmbientAuth
  let _node_name: String
  var _step_digests: DigestMap = DigestMap
  var _step_count: USize = 0
  var _boundary_summary: BoundaryMetricsSummary
  let _conn: (TCPConnection | None)
  let _max_batch: USize
  let _max_time: U64
  var _node_last_sent: U64 = Epoch.nanoseconds()
  var _boundary_last_sent: U64 = Epoch.nanoseconds()

	new create(auth: AmbientAuth, node_name: String,
             conn: (TCPConnection | None) = None, max_batch: USize = 10,
             max_time: U64 = 10_000_000_000) =>
	  _auth = auth
    _node_name = node_name
	  _conn = conn
    _max_batch = max_batch
    _max_time = max_time

	be report_step_metrics(step_id: U64, start_time: U64, end_time: U64) =>
	  try
	    _step_digests(step_id).add_report(StepMetricsReport(start_time, end_time))
	    _step_count = _step_count + 1
	  else
	    let dig = StepMetricsDigest(step_id)
	    dig.add_report(StepMetricsReport(start_time, end_time))
	    _step_digests(step_id) = dig
	    _step_count = _step_count + 1
		end
    _send_steps_if_over_max()

  be flush_step_metrics() =>
    _send_steps_if_over_max()

  fun ref _send_steps_if_over_max() =>
	  if (_step_count > _max_batch) or
       ((Epoch.nanoseconds() - _node_last_sent) > _max_time)
    then
      let summary = NodeMetricsSummary(_node_name)
      for digest in _step_digests do
        summary.add_digest(digest)
      end
	    _step_digests = DigestMap
	    _step_count = 0
      _send_step_metrics_to_receiver(consume summary)
      _node_last_sent = Epoch.nanoseconds()
	  end

  fun ref _send_step_metrics_to_receiver(summary: NodeMetricsSummary) =>
    match _conn
    | let c: TCPConnection =>
      let encoded = MetricsMsgEncoder.nodemetrics(summary, _auth)
      c.write(Bytes.length_encode(consume encoded))
    end

	be report_boundary_metrics(boundary_type: U64, msg_id: U64, start_time: U64,
		end_time: U64) =>
		_boundary_summary.add_report(BoundaryMetricsReport(boundary_type,
			msg_id, start_time, end_time))
    _send_bounary_if_over_max()

  be flush_boundary_metrics() =>
    _send_boundary_if_over_max()

  fun ref _send_boundary_if_over_max() =>
	  if (_boundary_summary.size() > _max_batch) or
       ((Epoch.nanoseconds() - _boundary_last_sent) > _max_time)
    then
	    _send_boundary_metrics_to_receiver(_boundary_summary)
	    _boundary_summary = BoundaryMetricsSummary
      _boundary_last_sent = epoch.nanoseconds()
	  end

  fun ref _send_boundary_metrics_to_receiver(summary: BoundaryMetriscSummary) =>
  	match _conn
  	| let c: TCPConnection =>
			let encoded = MetricsMsgEncoder.boundarymetrics(summary, _auth)
			c.write(Bytes.length_encode(consume encoded))
		end

class StepReporter
	let _step_id: U64
	let _metrics_collector: MetricsCollector

	new val create(s_id: U64, m_coll: MetricsCollector) =>
		_step_id = s_id
		_metrics_collector = m_coll

	fun report(start_time: U64, end_time: U64) =>
		_metrics_collector.report_step_metrics(_step_id, start_time, end_time)
