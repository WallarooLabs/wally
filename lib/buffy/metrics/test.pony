use "ponytest"
use "buffy/messages"
use "sendence/bytes"
use "collections"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestNodeReportsEncoder)
    test(_TestBoundaryReportsEncoder)

class iso _TestNodeReportsEncoder is UnitTest
  fun name(): String => "buffy:NodeReportsEncoder"

  fun apply(h: TestHelper) ? =>
    let node_name = "Test"
    let report_map = Map[_StepId, Array[StepMetricsReport val]]

    report_map(1) = Array[StepMetricsReport val]
    report_map(1).push(StepMetricsReport(100, 1232143143, 1354551314))
    report_map(1).push(StepMetricsReport(101, 1232347892, 1354328734))
    report_map(1).push(StepMetricsReport(102, 1242596283, 1123612344))
    report_map(1).push(StepMetricsReport(103, 1298273467, 1354275829))
    report_map(1).push(StepMetricsReport(104, 1223498726, 1313488791))

    report_map(2) = Array[StepMetricsReport val]
    report_map(2).push(StepMetricsReport(200, 1232143112, 1354551313))
    report_map(2).push(StepMetricsReport(201, 1232347867, 1354328748))
    report_map(2).push(StepMetricsReport(202, 1242596287, 1123612390))
    report_map(2).push(StepMetricsReport(203, 1298273412, 1354275808))
    report_map(2).push(StepMetricsReport(204, 1223498723, 1313488789))

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
    let boundary_report_map = Map[_StepId, Array[BoundaryMetricsReport val]]

    boundary_report_map(1) = Array[BoundaryMetricsReport val]
    boundary_report_map(1).push(BoundaryMetricsReport(0, 9143, 91351314))
    boundary_report_map(1).push(BoundaryMetricsReport(1, 9192, 91358734))
    boundary_report_map(1).push(BoundaryMetricsReport(2, 9183, 91122344))
    boundary_report_map(1).push(BoundaryMetricsReport(3, 9167, 91355829))
    boundary_report_map(1).push(BoundaryMetricsReport(1, 9126, 91318791))

    boundary_report_map(2) = Array[BoundaryMetricsReport val]
    boundary_report_map(2).push(BoundaryMetricsReport(0, 9143, 91354551))
    boundary_report_map(2).push(BoundaryMetricsReport(1, 9147, 91354328))
    boundary_report_map(2).push(BoundaryMetricsReport(2, 9196, 91123612))
    boundary_report_map(2).push(BoundaryMetricsReport(3, 9173, 91354275))
    boundary_report_map(2).push(BoundaryMetricsReport(0, 9198, 91313488))


    let boundary_encoded = BoundaryMetricsEncoder(boundary_node_name, boundary_report_map)

    let boundary_decoded = ReportMsgDecoder(consume boundary_encoded)

    match boundary_decoded
    | let n: BoundaryMetricsSummary val =>
      h.assert_eq[String](n.node_name, "BoundaryTest")
      h.assert_eq[U64](n.digests(0).reports(1).timestamp, 91354328)
    else
      h.fail("Wrong decoded message type")
    end

    true
