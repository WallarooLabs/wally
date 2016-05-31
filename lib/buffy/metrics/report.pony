use "sendence/bytes"
use "collections"
use "serialise"

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
  fun _serialise(msg: MetricsWireMsg val, auth: AmbientAuth): Array[U8] val ? =>
    let serialised: Array[U8] val =
      Serialised(SerialiseAuth(auth), msg).output(OutputSerialisedAuth(auth))
    Bytes.length_encode(serialised)

  fun nodemetrics(nodemetricssummary: NodeMetricsSummary, auth: AmbientAuth):
  Array[U8] val ? =>
    _serialise(consume nodemetricssummary, auth)

  fun boundarymetrics(boundarymetricssummary: BoundaryMetricsSummary,
                      auth: AmbientAuth): Array[U8] val ? =>
    _serialise(consume boundarymetricssummary, auth)

primitive MetricsMsgDecoder
  fun apply(data: Array[U8] val, auth: AmbientAuth): MetricsWireMsg val =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data)
        (DeserialiseAuth(auth))
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
  let digests: Array[StepMetricsDigest val] = Array[StepMetricsDigest val]

  new create(name: String) =>
    node_name = name

  fun ref add_digest(d: StepMetricsDigest val) =>
    digests.push(d)

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
  let reports: BoundaryReports = BoundaryReports

  new create(name: String) =>
    node_name = name

  fun size(): USize =>
    reports.size()

  fun ref add_report(r: BoundaryMetricsReport val) =>
    reports.push(r)

type StepType is U64
type StepId is U64
type DigestMap is Map[_StepId, StepMetricsDigest]
type BoundaryReports = Array[BoundaryMetricsReport val]
