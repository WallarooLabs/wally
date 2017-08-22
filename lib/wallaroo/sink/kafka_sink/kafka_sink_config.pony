use "net"
use "options"
use "pony-kafka"
use "pony-kafka/customlogger"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/sink"

primitive KafkaSinkConfigCLIParser
  fun opts(): Array[(String, (None | String), ArgumentType, (Required |
    Optional), String)]
  =>
    // items in the tuple are: Argument Name, Argument Short Name,
    //   Argument Type, Required or Optional, Help Text
    let opts_array = Array[(String, (None | String), ArgumentType, (Required |
      Optional), String)]

    opts_array.push(("kafka_sink_topic", None, StringArgument, Required,
      "Kafka topic to consume from"))
    opts_array.push(("kafka_sink_brokers", None, StringArgument, Required,
      "Initial brokers to connect to. Format: 'host:port,host:port,...'"))
    opts_array.push(("kafka_sink_log_level", None, StringArgument, Required,
      "Log Level (Fine, Info, Warn, Error)"))
    opts_array.push(("kafka_sink_max_produce_buffer_ms", None, I64Argument,
      Required, "# ms to buffer for producing to kafka"))
    opts_array.push(("kafka_sink_max_message_size", None, I64Argument, Required,
      "Max message size in bytes for producing to kafka"))

    opts_array

  fun print_usage(out: OutStream) =>
    for (long, short, arg_type, arg_req, help) in opts().values() do
      let short_str = match short
             | let s: String => "/-" + s
             else "" end

      let arg_type_str = match arg_type
             | StringArgument => "(String)"
             | I64Argument => "(Integer)"
             | F64Argument => "(Float)"
             else "" end

      out.print("--" + long + short_str + "       " + arg_type_str + "    "
        + help)
    end

  fun apply(args: Array[String] val, out: OutStream): KafkaConfig val ? =>
    var log_level: LogLevel = Warn

    var topic: String = ""
    var brokers = recover val Array[(String, I32)] end

    var max_message_size: I32 = 1000000
    var max_produce_buffer_ms: U64 = 0

    let options = Options(args, false)

    for (long, short, arg_type, arg_req, _) in opts().values() do
      options.add(long, short, arg_type, arg_req)
    end

    // TODO: implement all the other options that kafka client supports
    for option in options do
      match option
      | ("kafka_sink_max_produce_buffer_ms", let input: I64) =>
        max_produce_buffer_ms = input.u64()
      | ("kafka_sink_max_message_size", let input: I64) =>
        max_message_size = input.i32()
      | ("kafka_sink_topic", let input: String) =>
        topic = input
      | ("kafka_sink_brokers", let input: String) =>
        brokers = _brokers_from_input_string(input)
      | ("kafka_sink_log_level", let input: String) =>
        log_level = match input
          | "Fine" => Fine
          | "Info" => Info
          | "Warn" => Warn
          | "Error" => Error
          else
            let l = StringLogger(log_level, out)
            l(Error) and
              l.log(Error, "Error! Invalid kafka_sink_log_level: " + input)
            error
          end
      end
    end

    let logger = StringLogger(log_level, out)

    if (brokers.size() == 0) or (topic == "") then
      logger(Error) and
        logger.log(Error, "Error! Either brokers is empty or topics is empty!")
      error
    end

    // create kafka config
    recover val
      let kc = KafkaConfig(logger, "Wallaroo Kafka Sink " + topic where
        max_message_size' = max_message_size, max_produce_buffer_ms' =
        max_produce_buffer_ms)

      // add topic config to consumer
      kc.add_topic_config(topic, KafkaProduceOnly)

      for (host, port) in brokers.values() do
        kc.add_broker(host, port)
      end

      kc
    end

  fun _brokers_from_input_string(inputs: String): Array[(String, I32)] val ? =>
    let brokers = recover trn Array[(String, I32)] end

    for input in inputs.split(",").values() do
      let i = input.split(":")
      let host = i(0)
      let port: I32 = try i(1).i32() else 9092 end
      brokers.push((host, port))
    end

    consume brokers

  fun _topics_from_input_string(inputs: String): Array[String] val =>
    let topics = recover trn Array[String] end

    for input in inputs.split(",").values() do
      topics.push(input)
    end

    consume topics

class val KafkaSinkConfig[Out: Any val] is SinkConfig[Out]
  let _encoder: KafkaSinkEncoder[Out]
  let _conf: KafkaConfig val
  let _auth: TCPConnectionAuth

  new val create(encoder: KafkaSinkEncoder[Out], conf: KafkaConfig val,
    auth: TCPConnectionAuth)
  =>
    _encoder = encoder
    _conf = conf
    _auth = auth

  fun apply(): SinkBuilder =>
    KafkaSinkBuilder(TypedKafkaEncoderWrapper[Out](_encoder), _conf, _auth)

class val KafkaSinkBuilder
  let _encoder_wrapper: KafkaEncoderWrapper
  let _conf: KafkaConfig val
  let _auth: TCPConnectionAuth

  new val create(encoder_wrapper: KafkaEncoderWrapper, conf: KafkaConfig val,
    auth: TCPConnectionAuth)
  =>
    _encoder_wrapper = encoder_wrapper
    _conf = conf
    _auth = auth

  fun apply(reporter: MetricsReporter iso): Sink =>
    @printf[I32]("Creating Kafka Sink\n".cstring())

    KafkaSink(_encoder_wrapper, consume reporter, _conf, _auth)
