use "collections"
use "net"
use "buffy/messages"
use "sendence/bytes"

type _StepType is U32
type _StepId is U32

actor MetricsCollector
  let _env: Env
  let _node_name: String
  let _name_len_bytes: Array[U8] val
  let _source_id: U32
  let _sink_id: U32
  var _step_reports: Map[_StepId, Array[StepMetricsReport val]] = Map[_StepId, Array[StepMetricsReport val]]
  var _boundary_reports: Map[_StepId, Array[BoundaryMetricsReport val]] = Map[_StepId, Array[BoundaryMetricsReport val]]
  let _conn: TCPConnection

	new create(env: Env, node_name: String, source_id: I32, sink_id: I32,
	  conn: TCPConnection) =>
	  _env = env
	  _node_name = node_name
	  let name_bytes_length = _node_name.array().size().u32()
	  _name_len_bytes = Bytes.from_u32(name_bytes_length)
	  _source_id = source_id.u32()
	  _sink_id = sink_id.u32()
	  _conn = conn

	be report_metrics(s_id: I32, counter: U32, start_time: U64,
	  end_time: U64) =>
	  let step_id = s_id.u32()
	  try
	    _step_reports(step_id).push(StepMetricsReport(counter, start_time,
	      end_time))
	  else
	    let arr = Array[StepMetricsReport val]
	    arr.push(StepMetricsReport(counter, start_time, end_time))
	    _step_reports(step_id) = arr
      end
	  if _step_reports.size() > 10 then
	    _send_to_receiver()
	  end

  fun ref _send_to_receiver() =>
    let encoded = NodeMetricsEncoder(_node_name, _step_reports)
    _conn.write(Bytes.length_encode(consume encoded))

// double trigger: Send data either (1) at size 1MB (nominally for message on wire) or (2) on timeout // 100 milliseconds - 1 second
