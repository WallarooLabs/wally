use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/sink"

class val TCPSinkInformation[Out: Any val] is SinkInformation[Out]
  let _encoder: SinkEncoder[Out]
  let _host: String
  let _service: String
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(encoder: SinkEncoder[Out], host: String, service: String,
    initial_msgs: Array[Array[ByteSeq] val] val =
    recover Array[Array[ByteSeq] val] end)
  =>
    _encoder = encoder
    _initial_msgs = initial_msgs
    _host = host
    _service = service

  fun apply(): SinkBuilder =>
    TCPSinkBuilder(TypedEncoderWrapper[Out](_encoder), _host, _service,
      _initial_msgs)

class val TCPSinkBuilder
  let _encoder_wrapper: EncoderWrapper
  let _host: String
  let _service: String
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(encoder_wrapper: EncoderWrapper, host: String,
    service: String, initial_msgs: Array[Array[ByteSeq] val] val)
  =>
    _encoder_wrapper = encoder_wrapper
    _host = host
    _service = service
    _initial_msgs = initial_msgs

  fun apply(reporter: MetricsReporter iso): Sink =>
    @printf[I32](("Connecting to sink at " + _host + ":" + _service + "\n")
      .cstring())

    TCPSink(_encoder_wrapper, consume reporter, _host, _service,
      _initial_msgs)
