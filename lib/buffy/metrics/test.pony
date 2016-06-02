use "ponytest"
use "buffy/messages"
use "sendence/bytes"
use "collections"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)


  new make(env: Env) => None

  fun tag tests(test: PonyTest) =>
    test(_TestMetricsWireMsgNode)
    test(_TestMetricsWireMsgBoundary)
    test(_TestMonitoringHubEncoder)

class iso _TestMetricsWireMsgNode is UnitTest
  fun name(): String => "buffy:MetricsWireMsgNode"

  fun apply(h: TestHelper) ? =>
    let auth: AmbientAuth = h.env.root as AmbientAuth
    let node_name = "NodeTest"
    let nms = NodeMetricsSummary(node_name)
    nms.add_report(1, StepMetricsReport(1232143143, 1354551314))
    nms.add_report(1, StepMetricsReport(1232347892, 1354328734))
    nms.add_report(1, StepMetricsReport(1242596283, 1123612344))
    nms.add_report(1, StepMetricsReport(1298273467, 1354275829))
    nms.add_report(1, StepMetricsReport(1223498726, 1313488791))

    nms.add_report(2, StepMetricsReport(1232143112, 1354551313))
    nms.add_report(2, StepMetricsReport(1232347867, 1354328748))
    nms.add_report(2, StepMetricsReport(1242596287, 1123612390))
    nms.add_report(2, StepMetricsReport(1298273412, 1354275808))
    nms.add_report(2, StepMetricsReport(1223498723, 1313488789))


    let encoded = MetricsMsgEncoder.nodemetrics(nms, auth)
    // remove the bytes length segment from the array
    let e' = recover val encoded.slice(4) end
    let decoded = MetricsMsgDecoder(consume e', auth)
    match decoded
    | let n: NodeMetricsSummary val =>
      h.assert_eq[String](n.node_name, "NodeTest")
      h.assert_eq[U64](n.digests(2).reports(2).start_time, 1242596287)
      h.assert_eq[USize](n.size(), 10)
      h.assert_eq[U64](n.digests(1).reports(0).dt(),(1354551314-1232143143))
    else
      h.fail("Wrong decoded message type")
    end
    true

class iso _TestMetricsWireMsgBoundary is UnitTest
  fun name(): String => "buffy:MetricsWireMsgBoundary"

  fun apply(h: TestHelper) ? =>
    let auth: AmbientAuth = h.env.root as AmbientAuth
    let node_name = "BoundaryTest"
    let bms = BoundaryMetricsSummary(node_name)

    bms.add_report(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9143,
      91354551, 1232143112))
    bms.add_report(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9147,
      91354328, 1354328748))
    bms.add_report(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9196,
      91123612, 1313488789))
    bms.add_report(BoundaryMetricsReport(BoundaryTypes.source_sink(), 9173,
      91354275, 1313488789))
    bms.add_report(BoundaryMetricsReport(BoundaryTypes.ingress_egress(), 9198,
      91313488, 1354275829))

    let encoded = MetricsMsgEncoder.boundarymetrics(bms, auth)
    let e' = recover val encoded.slice(4) end
    let decoded = MetricsMsgDecoder(consume e', auth)

    match decoded
    | let n: BoundaryMetricsSummary val =>
      h.assert_eq[String](n.node_name, "BoundaryTest")
      h.assert_eq[U64](n.reports(1).start_time, 91354328)
      h.assert_eq[U64](n.reports(4).boundary_type,
        BoundaryTypes.ingress_egress())
      h.assert_eq[U64](n.reports(4).dt(), (1354275829-91313488))
    else
      h.fail("Wrong decoded message type")
    end

    true

class iso _TestMonitoringHubEncoder is UnitTest
  fun name(): String => "buffy:SinkMetricsEncoder"

  fun apply(h: TestHelper)  =>
    true
    /*
    let output = MetricsAccumulatorActor
    let handler: MetricsCollectionOutputHandler iso =
      recover iso MetricsStringAccumulator(MonitoringHubEncoder, output) end

    let bin_selector: F64Selector val = recover val Log10Selector end
    let mc: MetricsCollection = MetricsCollection(bin_selector, 1,
                                                  consume handler)

    let nms:NodeMetricsSummary iso = recover NodeMetricsSummary("node1") end
    let digest:StepMetricsDigest iso = recover StepMetricsDigest(999) end

    digest.add_report(StepMetricsReport(10010, 10550))
    digest.add_report(StepMetricsReport(10650, 12250))
    nms.add_digest(consume digest)

    let bms: BoundaryMetricsSummary iso = recover
      BoundaryMetricsSummary("node1") end
    bms.add_report(BoundaryMetricsReport(0, 10000, 10050, 10250))
    bms.add_report(BoundaryMetricsReport(0, 10001, 11150, 11600))
    bms.add_report(BoundaryMetricsReport(1, 10002, 15050, 15300))
    bms.add_report(BoundaryMetricsReport(1, 10003, 15400, 15500))

    let bms': BoundaryMetricsSummary val = consume bms
    let nms': NodeMetricsSummary val = consume nms
    // Process summaries for step, sink, and boundary
    mc.process_summary(nms')
    mc.process_summary(bms')

    // Process the collection with the handlers array
    mc.send_output()

    true
    */
