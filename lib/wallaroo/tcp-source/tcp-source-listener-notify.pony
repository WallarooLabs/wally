use "net"
use "wallaroo/metrics"
use "wallaroo/topology"
use "wallaroo/resilience"

interface SourceBuilder
  fun apply(): TCPSourceNotify iso^

interface SourceBuilderBuilder
  fun apply(runner_builder: RunnerBuilder val, router: Router val, 
    metrics_conn: TCPConnection, alfred: Alfred tag): SourceBuilder val 

class TypedSourceBuilderBuilder[In: Any val]
  let _name: String
  let _handler: FramedSourceHandler[In] val

  new val create(name': String, handler: FramedSourceHandler[In] val) =>
    _name = name'
    _handler = handler

  fun apply(runner_builder: RunnerBuilder val, router: Router val, 
    metrics_conn: TCPConnection, alfred: Alfred tag): SourceBuilder val 
  =>
    recover
      lambda()(runner_builder, router, metrics_conn, _name, _handler, alfred):
        TCPSourceNotify iso^ 
      =>
        let reporter = MetricsReporter(_name, metrics_conn)

        FramedSourceNotify[In](_name, _handler, runner_builder, router, 
          consume reporter, alfred)
      end
    end
  
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

  new iso create(builder: SourceBuilder val) =>
    _source_builder = builder

  fun ref connected(listen: TCPSourceListener ref): TCPSourceNotify iso^ =>
    _source_builder()

  // TODO: implement listening and especially not_listening


