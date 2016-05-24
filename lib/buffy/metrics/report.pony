use "sendence/bytes"
use "collections"

primitive ReportTypes
  fun step(): U64 => 0
  fun boundary(): U64 => 1

primitive BoundaryTypes
  fun source_sink(): U64 => 0
  fun ingress_egress(): U64 => 1

type ReportSummary is (NodeMetricsSummary | BoundaryMetricsSummary | None)

primitive NodeMetricsEncoder
  fun apply(name: String, reports_map: Map[_StepId, Array[StepMetricsReport val]]):
    Array[U8] iso^ =>
    var d: Array[U8] iso = recover Array[U8] end
    let name_bytes_length = name.array().size().u64()
    d.append(Bytes.from_u64(ReportTypes.step()))
    d.append(Bytes.from_u64(name_bytes_length))
    d.append(name)
    for (key, reports) in reports_map.pairs() do
      d = Bytes.from_u64(key, consume d)
      d = Bytes.from_u64(reports.size().u64(), consume d)
      for report in reports.values() do
        d = Bytes.from_u64(report.start_time, consume d)
        d = Bytes.from_u64(report.end_time, consume d)
      end
    end
    consume d

primitive BoundaryMetricsEncoder
  fun apply(name: String, reports: Array[BoundaryMetricsReport val]):
    Array[U8] iso^ =>
    var d: Array[U8] iso = recover Array[U8] end
    let name_bytes_length = name.array().size().u64()
    d.append(Bytes.from_u64(ReportTypes.boundary()))
    d.append(Bytes.from_u64(name_bytes_length))
    d.append(name)
    d = Bytes.from_u64(reports.size().u64(), consume d)
    for report in reports.values() do
      d = Bytes.from_u64(report.boundary_type, consume d)
      d = Bytes.from_u64(report.msg_id, consume d)
      d = Bytes.from_u64(report.start_time, consume d)
      d = Bytes.from_u64(report.end_time, consume d)
    end
    consume d

primitive ReportMsgDecoder
  fun apply(d: Array[U8] val): ReportSummary val ? =>
    let data: Array[U8] ref = d.clone()
    match Bytes.u64_from_idx(0, data)
    | ReportTypes.step() => _decode_node_summary(data)
    | ReportTypes.boundary() => _decode_boundary_summary(data)
    end

  fun _decode_node_summary(data: Array[U8]): NodeMetricsSummary val ? =>
    var data_idx: USize = 4
    var name_length = Bytes.u64_from_idx(data_idx, data)
    data_idx = data_idx + 8
    let name_arr: Array[U8] iso = recover Array[U8] end
    for i in Range(0, name_length.usize()) do
      name_arr.push(data(data_idx))
      data_idx = data_idx + 1
    end
    let name = String.from_array(consume name_arr)
    let node_summary: NodeMetricsSummary iso = recover NodeMetricsSummary(name) end
    while data_idx < data.size() do
      let id = Bytes.u64_from_idx(data_idx, data)
      data_idx = data_idx + 8
      let digest: StepMetricsDigest iso = recover StepMetricsDigest(id) end
      let report_count = Bytes.u64_from_idx(data_idx, data)
      data_idx = data_idx + 8
      for i in Range(0, report_count.usize()) do
        digest.add_report(_decode_next_step_report(data_idx, data))
        data_idx = data_idx + 16
      end
      node_summary.add_digest(consume digest)
    end
    consume node_summary

  fun _decode_next_step_report(i: USize, arr: Array[U8]): StepMetricsReport val ? =>
    var idx = i
    if arr.size() < (16 + idx) then error end
    let start_time = Bytes.u64_from_idx(idx, arr)
    idx = idx + 8
    let end_time = Bytes.u64_from_idx(idx, arr)
    StepMetricsReport(start_time, end_time)

  fun _decode_boundary_summary(data: Array[U8]): BoundaryMetricsSummary val ? =>
    var data_idx: USize = 4
    var name_length = Bytes.u64_from_idx(data_idx, data)
    data_idx = data_idx + 8
    let name_arr: Array[U8] iso = recover Array[U8] end
    for i in Range(0, name_length.usize()) do
      name_arr.push(data(data_idx))
      data_idx = data_idx + 1
    end
    let name = String.from_array(consume name_arr)
    let boundary_summary: BoundaryMetricsSummary iso = recover BoundaryMetricsSummary(name) end
    let report_count = Bytes.u64_from_idx(data_idx, data)
    data_idx = data_idx + 8
    for i in Range(0, report_count.usize()) do
      boundary_summary.add_report(_decode_next_boundary_report(data_idx, data))
      data_idx = data_idx + 32
    end
    consume boundary_summary

  fun _decode_next_boundary_report(i: USize, arr: Array[U8]): BoundaryMetricsReport val ? =>
    var idx = i
    if arr.size() < (24 + idx) then error end
    let boundary_type = Bytes.u64_from_idx(idx, arr)
    idx = idx + 8
    let msg_id = Bytes.u64_from_idx(idx, arr)
    idx = idx + 8
    let start_time = Bytes.u64_from_idx(idx, arr)
    idx = idx + 8
    let end_time = Bytes.u64_from_idx(idx, arr)
    idx = idx + 8
    BoundaryMetricsReport(boundary_type, msg_id, start_time, end_time)

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

class NodeMetricsSummary
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

class BoundaryMetricsSummary
  let node_name: String
  let reports: Array[BoundaryMetricsReport val] = Array[BoundaryMetricsReport val]

  new create(name: String) =>
    node_name = name

  fun ref add_report(r: BoundaryMetricsReport val) =>
    reports.push(r)
