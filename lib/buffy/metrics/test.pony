use "ponytest"
use "buffy/messages"
use "sendence/bytes"
use "collections"
use "itertools"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)


  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestNodeReportsEncoder)
    test(_TestBoundaryReportsEncoder)
    test(_TestMonitoringHubEncoder)

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

class iso _TestMonitoringHubEncoder is UnitTest
  fun name(): String => "buffy:SinkMetricsEncoder"

  fun apply(h: TestHelper)  =>
    let mc = MetricsCollection(Log10Selector, 1)
    
    let nms:NodeMetricsSummary iso = recover NodeMetricsSummary("node1") end
    let digest:StepMetricsDigest iso = recover StepMetricsDigest(999) end
    
    digest.add_report(StepMetricsReport(0, 50))
    digest.add_report(StepMetricsReport(50, 250))
    nms.add_digest(consume digest)
    
    let bms: BoundaryMetricsSummary iso = recover
      BoundaryMetricsSummary("node1") end
    bms.add_report(BoundaryMetricsReport(0, 10000, 50, 250))
    bms.add_report(BoundaryMetricsReport(0, 10000, 150, 600))
    bms.add_report(BoundaryMetricsReport(1, 10000, 50, 300))
    bms.add_report(BoundaryMetricsReport(1, 10000, 100, 500))

    // Process summaries for step, sink, and boundary
    mc(consume nms)
    mc(consume bms)

    // Create an array of handlers with a stdout handler
    let handlers: Array[MetricsCollectionOutputHandler] = 
      Array[MetricsCollectionOutputHandler]
    let encoder = MonitoringHubEncoder
    let handler = MetricsStringAccumulator(encoder)
    handlers.push(handler)

    // Process the collection with the handlers array
    mc.handle_output(handlers)
    
    // Compare output in the accumulator handler
    let expected: Array[String] = Array[String]
    expected.push("""[
  [
    {
      "topics": {
        "throughput_out": {
          "0": 2
        },
        "latency_bins": {
          "0.0001": 0,
          "overflow": 0,
          "0.1": 0,
          "0.01": 0,
          "1": 2,
          "0.001": 0,
          "1e-05": 0,
          "1e-06": 0
        }
      },
      "t1": 0,
      "t0": -1,
      "category": "source-sink",
      "pipeline_key": "sink-node1"
    }
  ],
  [
    {
      "topics": {
        "throughput_out": {
          "0": 2
        },
        "latency_bins": {
          "0.0001": 0,
          "overflow": 0,
          "0.1": 0,
          "0.01": 0,
          "1": 2,
          "0.001": 0,
          "1e-05": 0,
          "1e-06": 0
        }
      },
      "t1": 0,
      "t0": -1,
      "category": "ingress-egress",
      "pipeline_key": "boundary-node1"
    }
  ],
  [
    {
      "topics": {
        "throughput_out": {
          "0": 2
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
      "t1": 0,
      "t0": -1,
      "category": "step",
      "pipeline_key": "step-999"
    }
  ]
]""")

    for (o, e) in Zip2[String, String](handler.output.values(),
      expected.values()) do
      if o != e then h.fail("Output varies from expected") end
    end
    
    true
