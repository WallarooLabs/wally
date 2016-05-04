use "collections"
use "net"
use "buffy/messages"
use "sendence/bytes"

type _StepType is U32
type _StepId is U32

actor MetricsCollector
  let _env: Env
  let _node_name: String
  var _step_reports: Map[_StepId, Array[StepMetricsReport val]] = Map[_StepId, Array[StepMetricsReport val]]
  var _boundary_reports: Array[BoundaryMetricsReport val] = Array[BoundaryMetricsReport val]
  let _conn: TCPConnection

	new create(env: Env, node_name: String, conn: TCPConnection) =>
	  _env = env
	  _node_name = node_name
	  _conn = conn

	be report_step_metrics(s_id: I32, start_time: U64, end_time: U64) =>
	  let step_id = s_id.u32()
	  try
	    _step_reports(step_id).push(StepMetricsReport(start_time, end_time))
	  else
	    let arr = Array[StepMetricsReport val]
	    arr.push(StepMetricsReport(start_time, end_time))
	    _step_reports(step_id) = arr
      end
	  if _step_reports.size() > 10 then
	    _send_step_metrics_to_receiver()
	    _step_reports = Map[_StepId, Array[StepMetricsReport val]]
	  end

	be report_boundary_metrics(boundary_type: I32, msg_id: I32, timestamp: U64) =>
		_boundary_reports.push(BoundaryMetricsReport(boundary_type,
			msg_id, timestamp))

	  if _boundary_reports.size() > 10 then
	    _send_boundary_metrics_to_receiver()
	    _boundary_reports = Array[BoundaryMetricsReport val]
	  end

  fun ref _send_step_metrics_to_receiver() =>
    let encoded = NodeMetricsEncoder(_node_name, _step_reports)
    _conn.write(Bytes.length_encode(consume encoded))

  fun ref _send_boundary_metrics_to_receiver() =>
    let encoded = BoundaryMetricsEncoder(_node_name, _boundary_reports)
    _conn.write(Bytes.length_encode(consume encoded))
