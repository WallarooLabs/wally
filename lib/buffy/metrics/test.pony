use "ponytest"
use "buffy/messages"
use "sendence/bytes"
use "collections"

actor Main is TestList
  let env: Env
  new create(env': Env) =>
    env = env'
    PonyTest(env, this)


  new make(env': Env) => None
    env = env'

  fun tag tests(test: PonyTest) =>
    /*
    test(_TestNodeReportsEncoder(env))
    test(_TestBoundaryReportsEncoder(env))
    */
    test(_TestMonitoringHubEncoder)

class iso _TestNodeReportsEncoder is UnitTest
  let _env: Env

  new create(env: Env) =>
    _env = env

  fun name(): String => "buffy:NodeReportsEncoder"

  fun apply(h: TestHelper)  =>
    try
      let auth = _env.root as AmbientAuth
      true
    else
      false
    end
    /*

    let node_name = "Test"
    let nodemetricssummary = NodeMetricsSummary(node_name)
    let digest_1 = StepMetricsDigest(1)
    digest_1.add_report(StepMetricsReport(1232143143, 1354551314))
    digest_1.add_report(StepMetricsReport(1232347892, 1354328734))
    digest_1.add_report(StepMetricsReport(1242596283, 1123612344))
    digest_1.add_report(StepMetricsReport(1298273467, 1354275829))
    digest_1.add_report(StepMetricsReport(1223498726, 1313488791))

    let digest_2 = StepMetricsDigest(2)
    digest_2.add_report(StepMetricsReport(1232143112, 1354551313))
    digest_2.add_report(StepMetricsReport(1232347867, 1354328748))
    digest_2.add_report(StepMetricsReport(1242596287, 1123612390))
    digest_2.add_report(StepMetricsReport(1298273412, 1354275808))
    digest_2.add_report(StepMetricsReport(1223498723, 1313488789))

    nodemetricssummary.add_digest(digest_1)
    nodemetricssummary.add_digest(digest_2)

    let node_encoded = MetricsMsgEncoder.nodemetrics(nodemetricssummary,
      _auth)

    let node_decoded = MetricsMsgDecoder(consume node_encoded, _auth)

    match node_decoded
    | let n: NodeMetricsSummary val =>
      h.assert_eq[String](n.node_name, "Test")
      h.assert_eq[U64](n.digests(0).reports(2).start_time, 1242596287)
    else
      h.fail("Wrong decoded message type")
    end

    true
    */

class iso _TestBoundaryReportsEncoder is UnitTest
  let _env: Env

  new create(env: Env) =>
    _env = env

  fun name(): String => "buffy:BoundaryReportsEncoder"

  fun apply(h: TestHelper)  =>
    try
      let auth = _env.root as AmbientAuth
      true
    else
      false
    end
    /*
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
*/

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
