use "wallaroo/boundary"
use "wallaroo/metrics"
use "wallaroo/topology"

trait RouteBuilder
  fun apply(step: Producer ref, consumer: CreditFlowConsumerStep,
    metrics_reporter: MetricsReporter ref): Route

primitive TypedRouteBuilder[In: Any val] is RouteBuilder
  fun apply(step: Producer ref, consumer: CreditFlowConsumerStep,
    metrics_reporter: MetricsReporter ref): Route
  =>
    match consumer
    | let boundary: OutgoingBoundary =>
      BoundaryRoute(step, boundary, consume metrics_reporter)
    else
      TypedRoute[In](step, consumer, consume metrics_reporter)
    end

primitive EmptyRouteBuilder is RouteBuilder
  fun apply(step: Producer ref, consumer: CreditFlowConsumerStep,
    metrics_reporter: MetricsReporter ref): Route
  =>
    EmptyRoute
