use "collections"
use "wallaroo/boundary"
use "wallaroo/ent/data_receiver"
use "wallaroo/core"
use "wallaroo/initialization"
use "wallaroo/metrics"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/sink/tcp_sink"
use "wallaroo/source/tcp_source"
use "wallaroo/topology"

interface val SourceListenerBuilder
  fun apply(): SourceListener

interface val SourceListenerBuilderBuilder
  fun apply(source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry, route_builder: RouteBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder | None) = None,
    target_router: Router = EmptyRouter): SourceListenerBuilder
