use "sendence/bytes"
use "collections"

primitive ReportsEncoder
  fun apply(name: String, reports_map: Map[_StepId, Array[StepMetricsReport val]]):
    Array[U8] iso^ =>
    @printf[String]("Starting Encoding".cstring())
    var d: Array[U8] iso = recover Array[U8] end
    let name_bytes_length = name.array().size().u32()
    d.append(Bytes.from_u32(name_bytes_length))
    d.append(name)
    for (key, reports) in reports_map.pairs() do
      d = Bytes.from_u32(key, consume d)
      d = Bytes.from_u32(reports.size().u32(), consume d)
      for report in reports.values() do
        d = Bytes.from_u32(report.counter, consume d)
        d = Bytes.from_u64(report.start_time, consume d)
        d = Bytes.from_u64(report.end_time, consume d)
      end
    end
    consume d

primitive ReportMsgDecoder
  fun apply(data: Array[U8]): NodeMetricsReport val ? =>
    var name_length = Bytes.u32_from_idx(0, data)
    var data_idx: USize = 4
    let name_arr: Array[U8] iso = recover Array[U8] end
    for i in Range(0, name_length.usize()) do
      name_arr.push(data(data_idx))
      data_idx = data_idx + 1
    end
    let name = String.from_array(consume name_arr)
    let node_report: NodeMetricsReport iso = recover NodeMetricsReport(name) end
    while data_idx < data.size() do
      let id = Bytes.u32_from_idx(data_idx, data).i32()
      data_idx = data_idx + 4
      let digest: StepMetricsDigest iso = recover StepMetricsDigest(id) end
      let report_count = Bytes.u32_from_idx(data_idx, data)
      data_idx = data_idx + 4
      for i in Range(0, report_count.usize()) do
        digest.add_report(_decode_next_report(data_idx, data))
        data_idx = data_idx + 20
      end
      node_report.add_digest(consume digest)
    end
    consume node_report

  fun _decode_next_report(i: USize, arr: Array[U8]): StepMetricsReport val ? =>
    var idx = i
    if arr.size() < (20 + idx) then error end
    let counter = Bytes.u32_from_idx(idx, arr)
    idx = idx + 4
    let start_time = Bytes.u64_from_idx(idx, arr)
    idx = idx + 8
    let end_time = Bytes.u64_from_idx(idx, arr)
    StepMetricsReport(counter, start_time, end_time)

class StepMetricsReport
  let counter: U32
  let start_time: U64
  let end_time: U64

  new val create(c: U32, s_time: U64, e_time: U64) =>
    counter = c
    start_time = s_time
    end_time = e_time

class StepMetricsDigest
  let step_id: I32
  let reports: Array[StepMetricsReport val] = Array[StepMetricsReport val]

  new create(id: I32) =>
    step_id = id

  fun ref add_report(r: StepMetricsReport val) =>
    reports.push(r)

class NodeMetricsReport
  let node_name: String
  let digests: Array[StepMetricsDigest val] = Array[StepMetricsDigest val]

  new create(name: String) =>
    node_name = name

  fun ref add_digest(d: StepMetricsDigest val) =>
    digests.push(d)  
