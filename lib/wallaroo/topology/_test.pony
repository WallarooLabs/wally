use "collections"
use "ponytest"
use "sendence/equality"
use "wallaroo/boundary"
use "wallaroo/metrics"
use "wallaroo/resilience"
use "wallaroo/routing"

actor Main is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestLocalPartitionRouterEquality)
    test(_TestOmniRouterEquality)
    test(_TestDataRouterEqualityAfterRemove)
    test(_TestDataRouterEqualityAfterAdd)

class iso _TestLocalPartitionRouterEquality is UnitTest
  """
  Test that updating LocalPartitionRouter creates the expected changes

  Move step id 1 from worker w1 to worker w2.
  """
  fun name(): String =>
    "topology/LocalPartitionRouterEquality"

  fun ref apply(h: TestHelper) ? =>
    let alfred = Alfred(h.env)
    let auth = h.env.root as AmbientAuth

    let step1 = _StepGenerator(alfred)
    let step2 = _StepGenerator(alfred)
    let step3 = _StepGenerator(alfred)
    let boundary2 = _BoundaryGenerator("w1", auth)
    let boundary3 = _BoundaryGenerator("w1", auth)

    let base_local_map: Map[U128, Step] trn = recover Map[U128, Step] end
    base_local_map(1) = step1
    let target_local_map: Map[U128, Step] val = recover Map[U128, Step] end

    let base_step_ids: Map[String, U128] trn = recover Map[String, U128] end
    base_step_ids("k1") = 1
    base_step_ids("k2") = 2
    base_step_ids("k3") = 3
    let target_step_ids: Map[String, U128] trn = recover Map[String, U128] end
    target_step_ids("k1") = 1
    target_step_ids("k2") = 2
    target_step_ids("k3") = 3

    let new_proxy_router = ProxyRouter("w1", boundary2,
      ProxyAddress("w2", 1), auth)

    let base_partition_routes = _BasePartitionRoutesGenerator(alfred, auth,
      step1, boundary2, boundary3)
    let target_partition_routes = _TargetPartitionRoutesGenerator(alfred, auth,
      new_proxy_router, boundary2, boundary3)

    var base_router: PartitionRouter val =
      LocalPartitionRouter[String, String](consume base_local_map,
        consume base_step_ids, base_partition_routes,
      _PartitionFunctionGenerator(), _DefaultRouterGenerator())
    var target_router: PartitionRouter val =
      LocalPartitionRouter[String, String](consume target_local_map,
        consume target_step_ids, target_partition_routes,
        _PartitionFunctionGenerator(), _DefaultRouterGenerator())
    h.assert_eq[Bool](false, base_router == target_router)

    base_router = base_router.update_route[String]("k1", new_proxy_router)

    h.assert_eq[Bool](true, base_router == target_router)

class iso _TestOmniRouterEquality is UnitTest
  """
  Test that updating OmniRouter creates the expected changes

  Move step id 1 from worker w1 to worker w2.
  Move step id 2 from worker w2 to worker w1 (and point to step2)
  Add new boundary to worker 3
  """
  fun name(): String =>
    "topology/OmniRouterEquality"

  fun ref apply(h: TestHelper) ? =>
    let alfred = Alfred(h.env)
    let auth = h.env.root as AmbientAuth

    let step1 = _StepGenerator(alfred)
    let step2 = _StepGenerator(alfred)

    let boundary2 = _BoundaryGenerator("w1", auth)
    let boundary3 = _BoundaryGenerator("w1", auth)

    let base_data_routes: Map[U128, ConsumerStep tag] trn =
      recover Map[U128, ConsumerStep tag] end
    base_data_routes(1) = step1

    let target_data_routes: Map[U128, ConsumerStep tag] trn =
      recover Map[U128, ConsumerStep tag] end
    target_data_routes(2) = step2

    let base_step_map: Map[U128, (ProxyAddress val | U128)] trn =
      recover Map[U128, (ProxyAddress val | U128)] end
    base_step_map(1) = ProxyAddress("w1", 1)
    base_step_map(2) = ProxyAddress("w2", 2)

    let target_step_map: Map[U128, (ProxyAddress val | U128)] trn =
      recover Map[U128, (ProxyAddress val | U128)] end
    target_step_map(1) = ProxyAddress("w2", 1)
    target_step_map(2) = ProxyAddress("w1", 2)

    let base_boundaries: Map[String, OutgoingBoundary] trn =
      recover Map[String, OutgoingBoundary] end
    base_boundaries("w2") = boundary2

    let target_boundaries: Map[String, OutgoingBoundary] trn =
      recover Map[String, OutgoingBoundary] end
    target_boundaries("w2") = boundary2
    target_boundaries("w3") = boundary3

    var base_router: OmniRouter val = StepIdRouter("w1",
      consume base_data_routes, consume base_step_map,
      consume base_boundaries)

    let target_router: OmniRouter val = StepIdRouter("w1",
      consume target_data_routes, consume target_step_map,
      consume target_boundaries)

    h.assert_eq[Bool](false, base_router == target_router)

    base_router = base_router.update_route_to_proxy(1, ProxyAddress("w2", 1))
    base_router = base_router.update_route_to_step(2, step2)
    base_router = base_router.add_boundary("w3", boundary3)

    h.assert_eq[Bool](true, base_router == target_router)

class iso _TestDataRouterEqualityAfterRemove is UnitTest
  """
  Test that updating DataRouter creates the expected changes

  Remove route to step id 2
  """
  fun name(): String =>
    "topology/DataRouterEqualityAfterRemove"

  fun ref apply(h: TestHelper) ? =>
    let alfred = Alfred(h.env)
    let auth = h.env.root as AmbientAuth

    let step1 = _StepGenerator(alfred)
    let step2 = _StepGenerator(alfred)

    let base_routes: Map[U128, ConsumerStep tag] trn =
      recover Map[U128, ConsumerStep tag] end
    base_routes(1) = step1
    base_routes(2) = step2

    let target_routes: Map[U128, ConsumerStep tag] trn =
      recover Map[U128, ConsumerStep tag] end
    target_routes(1) = step1

    var base_router = DataRouter(consume base_routes)
    let target_router = DataRouter(consume target_routes)

    h.assert_eq[Bool](false, base_router == target_router)

    base_router = base_router.remove_route(2)

    h.assert_eq[Bool](true, base_router == target_router)

class iso _TestDataRouterEqualityAfterAdd is UnitTest
  """
  Test that updating DataRouter creates the expected changes

  Add route to step id 3
  """
  fun name(): String =>
    "topology/_TestDataRouterEqualityAfterAdd"

  fun ref apply(h: TestHelper) ? =>
    let alfred = Alfred(h.env)
    let auth = h.env.root as AmbientAuth

    let step1 = _StepGenerator(alfred)
    let step2 = _StepGenerator(alfred)

    let base_routes: Map[U128, ConsumerStep tag] trn =
      recover Map[U128, ConsumerStep tag] end
    base_routes(1) = step1

    let target_routes: Map[U128, ConsumerStep tag] trn =
      recover Map[U128, ConsumerStep tag] end
    target_routes(1) = step1
    target_routes(2) = step2

    var base_router = DataRouter(consume base_routes)
    let target_router = DataRouter(consume target_routes)

    h.assert_eq[Bool](false, base_router == target_router)

    base_router = base_router.add_route(2, step2)

    h.assert_eq[Bool](true, base_router == target_router)

primitive _BasePartitionRoutesGenerator
  fun apply(alfred: Alfred, auth: AmbientAuth, step1: Step,
    boundary2: OutgoingBoundary, boundary3: OutgoingBoundary):
    Map[String, (Step | ProxyRouter val)] val
  =>
    let m: Map[String, (Step | ProxyRouter val)] trn =
      recover Map[String, (Step | ProxyRouter val)] end
    m("k1") = step1
    m("k2") = ProxyRouter("w1", boundary2,
      ProxyAddress("w2", 2), auth)
    m("k3") = ProxyRouter("w1", boundary3,
      ProxyAddress("w3", 3), auth)
    consume m

primitive _TargetPartitionRoutesGenerator
  fun apply(alfred: Alfred, auth: AmbientAuth,
    new_proxy_router: ProxyRouter val, boundary2: OutgoingBoundary,
    boundary3: OutgoingBoundary): Map[String, (Step | ProxyRouter val)] val
  =>
    let m: Map[String, (Step | ProxyRouter val)] trn =
      recover Map[String, (Step | ProxyRouter val)] end
    m("k1") = new_proxy_router
    m("k2") = ProxyRouter("w1", boundary2,
      ProxyAddress("w2", 2), auth)
    m("k3") = ProxyRouter("w1", boundary3,
      ProxyAddress("w3", 3), auth)
    consume m

primitive _LocalMapGenerator
  fun apply(): Map[U128, Step] val =>
    recover Map[U128, Step] end

primitive _StepIdsGenerator
  fun apply(): Map[String, U128] val =>
    recover Map[String, U128] end

primitive _PartitionFunctionGenerator
  fun apply(): PartitionFunction[String, String] val =>
    {(s: String): String => s}

primitive _DefaultRouterGenerator
  fun apply(): (Router val | None) =>
    None

primitive _StepGenerator
  fun apply(alfred: Alfred): Step =>
    Step(RouterRunner, MetricsReporter("", "", MetricsSink("", "")),
      1, EmptyRouteBuilder, alfred, recover Map[String, OutgoingBoundary] end)

primitive _BoundaryGenerator
  fun apply(worker_name: String, auth: AmbientAuth): OutgoingBoundary =>
    OutgoingBoundary(auth, worker_name,
      MetricsReporter("", "", MetricsSink("", "")), "", "")
