use "collections"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/metrics"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/tcp_sink"
use "wallaroo/tcp_source"
use "wallaroo/topology"

interface val SourceListenerBuilder
  fun apply(): SourceListener

interface val SourceListenerBuilderBuilder
  fun apply(source_builder: SourceBuilder, router: Router val,
    router_registry: RouterRegistry, route_builder: RouteBuilder val,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder val] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder val | None) = None,
    target_router: Router val = EmptyRouter): SourceListenerBuilder
