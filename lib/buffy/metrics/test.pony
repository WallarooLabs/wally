use "debug"
use "ponytest"
use "buffy/messages"
use "sendence/bytes"
use "collections"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)


  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestNodeReportsEncoder)
    test(_TestBoundaryReportsEncoder)
    test(_TestSinkMetricsEncoder)

class iso _TestNodeReportsEncoder is UnitTest
  fun name(): String => "buffy:NodeReportsEncoder"

  fun apply(h: TestHelper) ? =>
    let node_name = "Test"
    let report_map = Map[_StepId, Array[StepMetricsReport val]]

    report_map(1) = Array[StepMetricsReport val]
    report_map(1).push(StepMetricsReport(1232143143, 1354551314))
    report_map(1).push(StepMetricsReport(1232347892, 1354328734))
    report_map(1).push(StepMetricsReport(1242596283, 1123612344))
    report_map(1).push(StepMetricsReport(1298273467, 1354275829))
    report_map(1).push(StepMetricsReport(1223498726, 1313488791))

    report_map(2) = Array[StepMetricsReport val]
    report_map(2).push(StepMetricsReport(1232143112, 1354551313))
    report_map(2).push(StepMetricsReport(1232347867, 1354328748))
    report_map(2).push(StepMetricsReport(1242596287, 1123612390))
    report_map(2).push(StepMetricsReport(1298273412, 1354275808))
    report_map(2).push(StepMetricsReport(1223498723, 1313488789))

    let node_encoded = NodeMetricsEncoder(node_name, report_map)

    let node_decoded = ReportMsgDecoder(consume node_encoded)

    match node_decoded
    | let n: NodeMetricsSummary val =>
      h.assert_eq[String](n.node_name, "Test")
      h.assert_eq[U64](n.digests(0).reports(2).start_time, 1242596287)
    else
      h.fail("Wrong decoded message type")
    end

    true

class iso _TestBoundaryReportsEncoder is UnitTest
  fun name(): String => "buffy:BoundaryReportsEncoder"

  fun apply(h: TestHelper) ? =>
    let boundary_node_name = "BoundaryTest"
    let boundary_reports = Array[BoundaryMetricsReport val]

    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9143, 91354551, 1232143112))
    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9147, 91354328, 1354328748))
    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9196, 91123612, 1313488789))
    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9173, 91354275, 1313488789))
    boundary_reports.push(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9198, 91313488, 1354275829))

    let boundary_encoded = BoundaryMetricsEncoder(boundary_node_name, boundary_reports)

    let boundary_decoded = ReportMsgDecoder(consume boundary_encoded)

    match boundary_decoded
    | let n: BoundaryMetricsSummary val =>
      h.assert_eq[String](n.node_name, "BoundaryTest")
      h.assert_eq[U64](n.reports(1).start_time, 91354328)
    else
      h.fail("Wrong decoded message type")
    end

    true

class iso _TestSinkMetricsEncoder is UnitTest
  fun name(): String => "buffy:SinkMetricsEncoder"

  fun apply(h: TestHelper)  =>
    let sm = SinkMetrics
    let tb = TimeBuckets
    sm.update("sink", tb)
    (let lh, let th) = (LatencyHistogram(Log10Selector),
                        recover ref ThroughputHistory end)
    tb.update(1, (lh, th))
    lh(StepMetricsReport(0, 100))
    lh(StepMetricsReport(50, 250))
    let encd: Array[U8] val = SinkMetricsEncoder(sm, 1)
    if encd.size() != 361 then h.fail("Encoded array is the wrong size") end
    let expected: String = """[
  {
    "topics": {
      "throughput_out": {
        "0": 0
      },
      "latency_bins": {
        "0.0001": 0,
        "overflow": 0,
        "0.1": 1,
        "0.01": 0,
        "1": 1,
        "0.001": 0,
        "1e-05": 0,
        "1e-06": 0
      }
    },
    "t1": 1,
    "t0": 0,
    "category": "source-sink",
    "pipeline_key": "sink-sink"
  }
]"""
    if String.from_array(encd) != expected then h.fail("Output varies from
      expected")
    end

    true
