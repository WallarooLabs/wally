use "ponytest"
use "buffy/messages"
use "sendence/bytes"
use "collections"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestReportsEncoder)

class iso _TestReportsEncoder is UnitTest
  fun name(): String => "buffy:ReportsEncoder"

  fun apply(h: TestHelper) ? =>
    let node_name = "Test"
    let report_map = Map[_StepId, Array[StepMetricsReport val]]

    report_map(1) = Array[StepMetricsReport val]
    report_map(1).push(StepMetricsReport(100, 1232143143, 1354551314))
    report_map(1).push(StepMetricsReport(101, 1232347892, 1354328734))
    report_map(1).push(StepMetricsReport(102, 1242596283, 1123612344))
    report_map(1).push(StepMetricsReport(103, 1298273467, 1354275829))
    report_map(1).push(StepMetricsReport(104, 1223498726, 1313488791))

    let id2: I32 = 2
    report_map(2) = Array[StepMetricsReport val]
    report_map(2).push(StepMetricsReport(200, 1232143112, 1354551313))
    report_map(2).push(StepMetricsReport(201, 1232347867, 1354328748))
    report_map(2).push(StepMetricsReport(202, 1242596287, 1123612390))
    report_map(2).push(StepMetricsReport(203, 1298273412, 1354275808))
    report_map(2).push(StepMetricsReport(204, 1223498723, 1313488789))

    let encoded = ReportsEncoder(node_name, report_map)

    let decoded = ReportMsgDecoder(consume encoded)

    h.assert_eq[String](decoded.node_name, "Test")
    h.assert_eq[U64](decoded.digests(1).reports(2).start_time, 1242596287)

    true
