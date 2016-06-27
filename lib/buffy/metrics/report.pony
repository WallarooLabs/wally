use "sendence/bytes"
use "collections"
use "serialise"
use "net"

primitive ReportTypes
  fun step(): U64 => 0
  fun boundary(): U64 => 1

primitive BoundaryTypes
  fun source_sink(): U64 => 0
  fun ingress_egress(): U64 => 1

type ReportSummary is (NodeMetricsSummary | BoundaryMetricsSummary | None)

trait val MetricsWireMsg

class UnknownMetricsMsg is MetricsWireMsg
  let data: Array[U8] val

  new val create(d: Array[U8] val) =>
    data = d

primitive MetricsMsgEncoder
  fun _encode(msg: MetricsWireMsg val, auth: AmbientAuth): 
    Array[ByteSeq] val ? 
  =>
    let serialised: Array[U8] val =
      Serialised(SerialiseAuth(auth), msg).output(OutputSerialisedAuth(auth))
    let wb = WriteBuffer
    let size = serialised.size()
    wb.u32_be(size.u32())
    wb.write(serialised)
    wb.done()

  fun nodemetrics(summary: NodeMetricsSummary val, auth: AmbientAuth):
    Array[ByteSeq] val ? =>
    _encode(summary, auth)

  fun boundarymetrics(summary: BoundaryMetricsSummary val,
                      auth: AmbientAuth): Array[ByteSeq] val ? =>
    _encode(summary, auth)

primitive MetricsMsgDecoder
  fun apply(data: Array[U8] val, auth: AmbientAuth): MetricsWireMsg val =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data)
        .apply(DeserialiseAuth(auth))
      | let m: MetricsWireMsg val => m
      else
        UnknownMetricsMsg(data)
      end
    else
      UnknownMetricsMsg(data)
    end

interface MetricsReport
  fun dt(): U64
  fun ended(): U64
  fun started(): U64

class StepMetricsReport is MetricsReport
  let start_time: U64
  let end_time: U64

  new val create(s_time: U64, e_time: U64) =>
    start_time = s_time
    end_time = e_time

  fun dt(): U64 => end_time - start_time
  fun started(): U64 => start_time
  fun ended(): U64 => end_time

class StepMetricsDigest
  let step_id: U64
  let reports: Array[StepMetricsReport val] = Array[StepMetricsReport val]

  new create(id: U64) =>
    step_id = id

  fun ref add_report(r: StepMetricsReport val) =>
    reports.push(r)

class NodeMetricsSummary is MetricsWireMsg
  let node_name: String
  let digests: DigestMap trn
  var _size: USize = 0

  new create(name: String, len: USize = 0) =>
    node_name = name
    digests = recover DigestMap(len) end

  fun size(): USize =>
    _size

  fun ref add_report(step_id: StepId val, r: StepMetricsReport val) =>
    if digests.contains(step_id) then
      try
        digests(step_id).add_report(r)
        _size = _size + 1
      end
    else
      let dig: StepMetricsDigest trn = recover StepMetricsDigest(step_id) end
      dig.add_report(r)
      digests.update(step_id, consume dig)
      _size = _size + 1
    end

class BoundaryMetricsReport is MetricsReport
  let boundary_type: U64
  let msg_id: U64
  let start_time: U64
  let end_time: U64

  new val create(b_type: U64, m_id: U64, s_ts: U64, e_ts: U64) =>
    boundary_type = b_type
    msg_id = m_id
    start_time = s_ts
    end_time = e_ts

  fun dt(): U64 => end_time - start_time
  fun started(): U64 => start_time
  fun ended(): U64 => end_time

class BoundaryMetricsSummary is MetricsWireMsg
  let node_name: String
  let reports: BoundaryReports trn 

  new create(name: String, len: USize = 0) =>
    node_name = name
    reports = recover BoundaryReports(len) end

  fun size(): USize =>
    reports.size()

  fun ref add_report(r: BoundaryMetricsReport val) =>
    reports.push(r)

type StepType is U64
type StepId is U64
type DigestMap is Map[StepId val, StepMetricsDigest trn]
type BoundaryReports is Array[BoundaryMetricsReport val]
