class TCPSourceInformation[In: Any val]
  let _handler: FramedSourceHandler[In] val
  let _host: String
  let _service: String

  new val create(handler': FramedSourceHandler[In] val, host': String, service': String) =>
    _handler = handler'
    _host = host'
    _service = service'

  fun handler(): FramedSourceHandler[In] val =>
    _handler

  fun host(): String =>
    _host

  fun service(): String =>
    _service

  fun source_listener_builder_builder(): TCPSourceListenerBuilderBuilder val =>
    TCPSourceListenerBuilderBuilder
