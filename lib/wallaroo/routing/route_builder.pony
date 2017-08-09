use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/topology"

trait RouteBuilder
  fun apply(step: Producer ref, consumer: ConsumerStep,
    metrics_reporter: MetricsReporter ref): Route

primitive TypedRouteBuilder[In: Any val] is RouteBuilder
  fun apply(step: Producer ref, consumer: ConsumerStep,
    metrics_reporter: MetricsReporter ref): Route
  =>
    match consumer
    | let boundary: OutgoingBoundary =>
      BoundaryRoute(step, boundary, consume metrics_reporter)
    else
      TypedRoute[In](step, consumer, consume metrics_reporter)
    end

primitive BoundaryOnlyRouteBuilder is RouteBuilder
  fun apply(step: Producer ref, consumer: ConsumerStep,
    metrics_reporter: MetricsReporter ref): Route
  =>
    match consumer
    | let boundary: OutgoingBoundary =>
      BoundaryRoute(step, boundary, consume metrics_reporter)
    else
      Fail()
      EmptyRoute
    end

