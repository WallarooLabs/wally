use "wallaroo/messages"
use "wallaroo/metrics"

class val TCPSinkBuilder
  let _encoder_wrapper: EncoderWrapper
  let _initial_msgs: Array[Array[ByteSeq] val] val

  new val create(encoder_wrapper: EncoderWrapper,
    initial_msgs: Array[Array[ByteSeq] val] val)
  =>
    _encoder_wrapper = encoder_wrapper
    _initial_msgs = initial_msgs

  fun apply(reporter: MetricsReporter iso, host: String, service: String):
    TCPSink
  =>
    TCPSink(_encoder_wrapper, consume reporter, host, service,
      _initial_msgs)
