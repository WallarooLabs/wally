use "options"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/sink"

primitive TCPSinkConfigCLIParser
  fun apply(args: Array[String] val): Array[TCPSinkConfigOptions] val ? =>
    let out_arg = "out"

    let options = Options(args, false)

    options.add(out_arg where arg = StringArgument, mode = Required)

    for option in options do
      match option
      | (out_arg, let output: String) =>
        return _from_output_string(output)
      end
    end

    error

  fun _from_output_string(outputs: String): Array[TCPSinkConfigOptions] val ? =>
    let opts = recover trn Array[TCPSinkConfigOptions] end

    for output in outputs.split(",").values() do
      let o = outputs.split(":")
      opts.push(TCPSinkConfigOptions(o(0), o(1)))
    end

    consume opts

class val TCPSinkConfigOptions
  let host: String
  let service: String

  new val create(host': String, service': String) =>
    host = host'
    service = service'

class val TCPSinkConfig[Out: Any val] is SinkConfig[Out]
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

  new val from_options(encoder: SinkEncoder[Out], opts: TCPSinkConfigOptions,
    initial_msgs: Array[Array[ByteSeq] val] val =
    recover Array[Array[ByteSeq] val] end)
  =>
    _encoder = encoder
    _initial_msgs = initial_msgs
    _host = opts.host
    _service = opts.service


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
