use "../backpressure"
use "../tcp-sink"

class Runner
  let _sink: TCPSink

  new val create(sink: TCPSink) =>
    _sink = sink

  fun process(free_candy: CreditFlowProducer ref, data: Array[U8] val) =>
    _sink.run(data)
    free_candy.credit_used(_sink)
