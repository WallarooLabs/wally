use "sendence/bytes"
use "collections"

primitive ReportTypes
  fun step(): U32 => 0
  fun boundary(): U32 => 1

primitive BoundaryTypes
  fun source_sink(): I32 => 0
  fun ingress_egress(): I32 => 1

type ReportSummary is (NodeMetricsSummary | BoundaryMetricsSummary | None)

primitive NodeMetricsEncoder
  fun apply(name: String, reports_map: Map[_StepId, Array[StepMetricsReport val]]):
    Array[U8] iso^ =>
    var d: Array[U8] iso = recover Array[U8] end
    let name_bytes_length = name.array().size().u32()
    d.append(Bytes.from_u32(ReportTypes.step()))
    d.append(Bytes.from_u32(name_bytes_length))
    d.append(name)
    for (key, reports) in reports_map.pairs() do
      d = Bytes.from_u32(key, consume d)
      d = Bytes.from_u32(reports.size().u32(), consume d)
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
    let name_bytes_length = name.array().size().u32()
    d.append(Bytes.from_u32(ReportTypes.boundary()))
    d.append(Bytes.from_u32(name_bytes_length))
    d.append(name)
    d = Bytes.from_u32(reports.size().u32(), consume d)
    for report in reports.values() do
      d = Bytes.from_u32(report.boundary_type.u32(), consume d)
      d = Bytes.from_u32(report.msg_id.u32(), consume d)
      d = Bytes.from_u64(report.start_time, consume d)
      d = Bytes.from_u64(report.end_time, consume d)
    end
    consume d

primitive ReportMsgDecoder
  fun apply(d: Array[U8] val): ReportSummary val ? =>
    let data: Array[U8] ref = d.clone()
    match Bytes.u32_from_idx(0, data)
    | ReportTypes.step() => _decode_node_summary(data)
    | ReportTypes.boundary() => _decode_boundary_summary(data)
    end

  fun _decode_node_summary(data: Array[U8]): NodeMetricsSummary val ? =>
    var data_idx: USize = 4
    var name_length = Bytes.u32_from_idx(data_idx, data)
    data_idx = data_idx + 4
    let name_arr: Array[U8] iso = recover Array[U8] end
    for i in Range(0, name_length.usize()) do
      name_arr.push(data(data_idx))
      data_idx = data_idx + 1
    end
    let name = String.from_array(consume name_arr)
    let node_summary: NodeMetricsSummary iso = recover NodeMetricsSummary(name) end
    while data_idx < data.size() do
      let id = Bytes.u32_from_idx(data_idx, data).i32()
      data_idx = data_idx + 4
      let digest: StepMetricsDigest iso = recover StepMetricsDigest(id) end
      let report_count = Bytes.u32_from_idx(data_idx, data)
      data_idx = data_idx + 4
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
    var name_length = Bytes.u32_from_idx(data_idx, data)
    data_idx = data_idx + 4
    let name_arr: Array[U8] iso = recover Array[U8] end
    for i in Range(0, name_length.usize()) do
      name_arr.push(data(data_idx))
      data_idx = data_idx + 1
    end
    let name = String.from_array(consume name_arr)
    let boundary_summary: BoundaryMetricsSummary iso = recover BoundaryMetricsSummary(name) end
    let report_count = Bytes.u32_from_idx(data_idx, data)
    data_idx = data_idx + 4
    for i in Range(0, report_count.usize()) do
      boundary_summary.add_report(_decode_next_boundary_report(data_idx, data))
      data_idx = data_idx + 24
    end
    consume boundary_summary

  fun _decode_next_boundary_report(i: USize, arr: Array[U8]): BoundaryMetricsReport val ? =>
    var idx = i
    if arr.size() < (16 + idx) then error end
    let boundary_type = Bytes.u32_from_idx(idx, arr).i32()
    idx = idx + 4
    let msg_id = Bytes.u32_from_idx(idx, arr).i32()
    idx = idx + 4
    let start_time = Bytes.u64_from_idx(idx, arr)
    idx = idx + 8
    let end_time = Bytes.u64_from_idx(idx, arr)
    idx = idx + 8
    BoundaryMetricsReport(boundary_type, msg_id, start_time, end_time)

class StepMetricsReport
  let start_time: U64
  let end_time: U64

  new val create(s_time: U64, e_time: U64) =>
    start_time = s_time
    end_time = e_time

class StepMetricsDigest
  let step_id: I32
  let reports: Array[StepMetricsReport val] = Array[StepMetricsReport val]

  new create(id: I32) =>
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

class BoundaryMetricsReport
  let boundary_type: I32
  let msg_id: I32
  let start_time: U64
  let end_time: U64

  new val create(b_type: I32, m_id: I32, s_ts: U64, e_ts: U64) =>
    boundary_type = b_type
    msg_id = m_id
    start_time = s_ts
    end_time = e_ts

class BoundaryMetricsSummary
  let node_name: String
  let reports: Array[BoundaryMetricsReport val] = Array[BoundaryMetricsReport val]

  new create(name: String) =>
    node_name = name

  fun ref add_report(r: BoundaryMetricsReport val) =>
    reports.push(r)
