use "net"
use "wallaroo/metrics"
use "wallaroo/topology"
use "wallaroo/resilience"

interface SourceBuilder
  fun name(): String
  fun apply(alfred: Alfred tag, auth: AmbientAuth, target_router: Router val):
    TCPSourceNotify iso^

class _SourceBuilder[In: Any val]
  let _app_name: String
  let _worker_name: String
  let _name: String
  let _runner_builder: RunnerBuilder val
  let _handler: FramedSourceHandler[In] val
  let _router: Router val
  let _metrics_conn: MetricsSink
  let _pre_state_target_id: (U128 | None)
  let _metrics_reporter: MetricsReporter

  new val create(app_name: String, worker_name: String,
    name': String,
    runner_builder: RunnerBuilder val,
    handler: FramedSourceHandler[In] val,
    router: Router val, metrics_conn: MetricsSink,
    pre_state_target_id: (U128 | None) = None,
    metrics_reporter: MetricsReporter iso)
  =>
    _app_name = app_name
    _worker_name = worker_name
    _name = name'
    _runner_builder = runner_builder
    _handler = handler
    _router = router
    _metrics_conn = metrics_conn
    _pre_state_target_id = pre_state_target_id
    _metrics_reporter = consume metrics_reporter

  fun name(): String => _name

  fun apply(alfred: Alfred tag, auth: AmbientAuth, target_router: Router val):
    TCPSourceNotify iso^
  =>
    FramedSourceNotify[In](_name, auth, _handler, _runner_builder, _router,
      _metrics_reporter.clone(), alfred, target_router, _pre_state_target_id)

interface SourceBuilderBuilder
  fun name(): String
  fun apply(runner_builder: RunnerBuilder val, router: Router val,
    metrics_conn: MetricsSink, pre_state_target_id: (U128 | None) = None,
    worker_name: String,
    metrics_reporter: MetricsReporter iso):
      SourceBuilder val

class TypedSourceBuilderBuilder[In: Any val]
  let _app_name: String
  let _name: String
  let _handler: FramedSourceHandler[In] val

  new val create(app_name: String, name': String,
    handler: FramedSourceHandler[In] val)
  =>
    _app_name = app_name
    _name = name'
    _handler = handler

  fun name(): String => _name

  fun apply(runner_builder: RunnerBuilder val, router: Router val,
    metrics_conn: MetricsSink, pre_state_target_id: (U128 | None) = None,
    worker_name: String, metrics_reporter: MetricsReporter iso):
      SourceBuilder val
  =>
    _SourceBuilder[In](_app_name, worker_name,
      _name, runner_builder, _handler, router,
      metrics_conn, pre_state_target_id, consume metrics_reporter)

interface TCPSourceListenerNotify
  """
  Notifications for TCPSource listeners.
  """
  fun ref listening(listen: TCPSourceListener ref) =>
    """
    Called when the listener has been bound to an address.
    """
    None

  fun ref not_listening(listen: TCPSourceListener ref) =>
    """
    Called if it wasn't possible to bind the listener to an address.
    """
    None

  fun ref connected(listen: TCPSourceListener ref): TCPSourceNotify iso^ ?
    """
    Create a new TCPSourceNotify to attach to a new TCPSource for a
    newly established connection to the server.
    """

class SourceListenerNotify is TCPSourceListenerNotify
  let _source_builder: SourceBuilder val
  let _alfred: Alfred tag
  let _target_router: Router val
  let _auth: AmbientAuth

  new iso create(builder: SourceBuilder val, alfred: Alfred tag, auth: AmbientAuth,
    target_router: Router val) =>
    _source_builder = builder
    _alfred = alfred
    _target_router = target_router
    _auth = auth

  fun ref listening(listen: TCPSourceListener ref) =>
    @printf[I32]((_source_builder.name() + " source is listening\n").cstring())

  fun ref connected(listen: TCPSourceListener ref): TCPSourceNotify iso^ =>
    _source_builder(_alfred, _auth, _target_router)

  // TODO: implement listening and especially not_listening


