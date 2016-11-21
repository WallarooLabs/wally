use "net"
use "wallaroo/metrics"
use "wallaroo/topology"
use "wallaroo/resilience"

interface SourceBuilder
  fun name(): String
  fun apply(alfred: Alfred tag, target_router: Router val): 
    TCPSourceNotify iso^

class _SourceBuilder[In: Any val]
  let _app_name: String
  let _name: String
  let _runner_builder: RunnerBuilder val
  let _handler: FramedSourceHandler[In] val
  let _router: Router val
  let _metrics_conn: TCPConnection  

  new val create(app_name: String, name': String, 
    runner_builder: RunnerBuilder val, 
    handler: FramedSourceHandler[In] val,
    router: Router val, metrics_conn: TCPConnection) 
  =>
    _app_name = app_name
    _name = name'
    _runner_builder = runner_builder
    _handler = handler
    _router = router
    _metrics_conn = metrics_conn

  fun name(): String => _name

  fun apply(alfred: Alfred tag, target_router: Router val): 
    TCPSourceNotify iso^ 
  =>
    let reporter = MetricsReporter(_app_name, _metrics_conn)

    FramedSourceNotify[In](_name, _handler, _runner_builder, _router, 
      consume reporter, alfred, target_router)

interface SourceBuilderBuilder
  fun name(): String
  fun apply(runner_builder: RunnerBuilder val, router: Router val, 
    metrics_conn: TCPConnection): SourceBuilder val 

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
    metrics_conn: TCPConnection): SourceBuilder val 
  =>
    _SourceBuilder[In](_app_name, _name, runner_builder, _handler, router,
      metrics_conn)
  
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

  new iso create(builder: SourceBuilder val, alfred: Alfred tag,
    target_router: Router val) =>
    _source_builder = builder
    _alfred = alfred
    _target_router = target_router

  fun ref listening(listen: TCPSourceListener ref) =>
    @printf[I32]((_source_builder.name() + " source is listening\n").cstring())

  fun ref connected(listen: TCPSourceListener ref): TCPSourceNotify iso^ =>
    _source_builder(_alfred, _target_router)

  // TODO: implement listening and especially not_listening


