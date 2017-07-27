use "wallaroo/source"

class TCPSourceInformation[In: Any val]
  let _handler: FramedSourceHandler[In] val
  let _host: String
  let _service: String

  new val create(handler': FramedSourceHandler[In] val, host': String, service': String) =>
    _handler = handler'
    _host = host'
    _service = service'

  fun source_listener_builder_builder(): TCPSourceListenerBuilderBuilder val =>
    TCPSourceListenerBuilderBuilder

  fun source_builder(app_name: String, name: String):
    TypedTCPSourceBuilderBuilder[In]
  =>
    TypedTCPSourceBuilderBuilder[In](app_name, name, _handler, _host, _service)
