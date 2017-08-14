use "net"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/source"
use "wallaroo/topology"
use "wallaroo/recovery"


class val TypedTCPSourceBuilderBuilder[In: Any val]
  let _app_name: String
  let _name: String
  let _handler: FramedSourceHandler[In] val
  let _host: String
  let _service: String

  new val create(app_name: String, name': String,
    handler: FramedSourceHandler[In] val, host': String, service': String)
  =>
    _app_name = app_name
    _name = name'
    _handler = handler
    _host = host'
    _service = service'

  fun name(): String => _name

  fun apply(runner_builder: RunnerBuilder, router: Router,
    metrics_conn: MetricsSink, pre_state_target_id: (U128 | None) = None,
    worker_name: String, metrics_reporter: MetricsReporter iso):
      SourceBuilder
  =>
    BasicSourceBuilder[In, FramedSourceHandler[In] val](_app_name, worker_name,
      _name, runner_builder, _handler, router,
      metrics_conn, pre_state_target_id, consume metrics_reporter,
      TCPFramedSourceNotifyBuilder[In])

  fun host(): String =>
    _host

  fun service(): String =>
    _service

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

  fun ref update_router(router: Router)

class SourceListenerNotify is TCPSourceListenerNotify
  var _source_builder: SourceBuilder
  let _event_log: EventLog
  let _target_router: Router
  let _auth: AmbientAuth

  new iso create(builder: SourceBuilder, event_log: EventLog, auth: AmbientAuth,
    target_router: Router) =>
    _source_builder = builder
    _event_log = event_log
    _target_router = target_router
    _auth = auth

  fun ref listening(listen: TCPSourceListener ref) =>
    @printf[I32]((_source_builder.name() + " source is listening\n").cstring())

  fun ref not_listening(listen: TCPSourceListener ref) =>
    @printf[I32](
      (_source_builder.name() + " source is unable to listen\n").cstring())
    Fail()

  fun ref connected(listen: TCPSourceListener ref): TCPSourceNotify iso^ ? =>
    try
      _source_builder(_event_log, _auth, _target_router) as TCPSourceNotify iso^
    else
      @printf[I32](
        (_source_builder.name() + " could not create a TCPSourceNotify\n").cstring())
      Fail()
      error
    end

  fun ref update_router(router: Router) =>
    _source_builder = _source_builder.update_router(router)
