use "collections"
use "net"
use "../messages"
use "sendence/bytes"

type _StepType is U32
type _StepId is U32

actor MetricsCollector
  let _env: Env
  let _node_name: String
  let _source_id: U32
  let _sink_id: U32
  var _reports: Map[_StepId, Array[MetricsReport val]] = Map[_StepId, Array[MetricsReport val]]
  let _conn: TCPConnection

	new create(env: Env, node_name: String, source_id: I32, sink_id: I32,
	  conn: TCPConnection) =>
	  _env = env
	  _node_name = node_name
	  _source_id = source_id.u32()
	  _sink_id = sink_id.u32()
	  _conn = conn

	be report_metrics(s_id: I32, counter: U32, start_time: U64,
	  end_time: U64) =>
	  let step_id = s_id.u32()
	  try
	    _reports(step_id).push(MetricsReport(counter, start_time,
	      end_time))
	  else
	    let arr = Array[MetricsReport val]
	    arr.push(MetricsReport(counter, start_time, end_time))
	    _reports(step_id) = arr
    end
    if _reports.size() > 10 then
      _send_to_receiver()
    end

  fun _send_to_receiver() =>
    var d: Array[U8] iso = recover Array[U8] end
    d.append(_node_name)
    for (key, reports) in _reports.pairs() do
      d = Bytes.from_u32(key, consume d)
      d = Bytes.from_u32(reports.size().u32(), consume d)
      for report in reports.values() do
        d = Bytes.from_u32(report.counter, consume d)
        d = Bytes.from_u32(report.start_time.u32(), consume d)
        d = Bytes.from_u32(report.end_time.u32(), consume d)
      end
    end
    _conn.write(Bytes.length_encode(consume d))

class MetricsReport
  let counter: U32
  let start_time: U64
  let end_time: U64

	new val create(c: U32, s_time: U64, e_time: U64) =>
	  counter = c
	  start_time = s_time
	  end_time = e_time

// double trigger: Send data either (1) at size 1MB (nominally for message on wire) or (2) on timeout // 100 milliseconds - 1 second
