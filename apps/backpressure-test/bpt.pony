use "wallaroo/tcp-source"
use "wallaroo/tcp-sink"

class MySourceBuilder is SourceBuilder
  let _handler: MyHandler val
  let _runner: Runner val

  new iso create(handler: MyHandler val, runner: Runner val) =>
    _handler = handler
    _runner = runner

  fun name(): String => "test"

  fun ref apply(listen: TCPSourceListener ref): TCPSourceNotify iso^ =>
    FramedSourceNotify(_handler, _runner)

primitive MyHandler is FramedSourceHandler
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] iso): Array[U8] val =>
    consume data

actor Main
  new create(env: Env) =>
    let sink = TCPSink("127.0.0.1", "8000")
    let runner = Runner(sink)
    // we shouldnt be passing a runner to user supplied code.
    // its a behind the scenes thing
    // maybe "MySourceBuilder" is a behind the scenes thing
    let builder = MySourceBuilder(MyHandler, runner)
    let consumers: Array[CreditFlowConsumer] trn = recover trn Array[CreditFlowConsumer] end
    consumers.push(sink)
    let c: Array[CreditFlowConsumer] val = consume consumers
    let listener = TCPSourceListener(consume builder,
      c,
      "127.0.0.1", "7000")
    let builder2 = MySourceBuilder(MyHandler, runner)
    let listener2 = TCPSourceListener(consume builder2,
      c,
      "127.0.0.1", "7001")
