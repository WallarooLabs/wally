use "net"
use "options"
use "pony-kafka"
use "pony-kafka/customlogger"
use "wallaroo/source"


primitive KafkaSourceConfigCLIParser
  fun opts(): Array[(String, (None | String), ArgumentType,
    (Required | Optional), String)]
  =>
    // items in the tuple are: Argument Name, Argument Short Name,
    //   Argument Type, Required or Optional, Help Text
    let opts_array = Array[(String, (None | String), ArgumentType,
      (Required | Optional), String)]

    opts_array.push(("kafka_source_topic", None, StringArgument, Required,
      "Kafka topic to consume from"))
    opts_array.push(("kafka_source_brokers", None, StringArgument, Required,
      "Initial brokers to connect to. Format: 'host:port,host:port,...'"))
    opts_array.push(("kafka_source_log_level", None, StringArgument, Required,
      "Log Level (Fine, Info, Warn, Error)"))

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

    let options = Options(args, false)

    for (long, short, arg_type, arg_req, _) in opts().values() do
      options.add(long, short, arg_type, arg_req)
    end

    // TODO: implement all the other options that kafka client supports
    for option in options do
      match option
      | ("kafka_source_topic", let input: String) =>
        topic = input
      | ("kafka_source_brokers", let input: String) =>
        brokers = _brokers_from_input_string(input)
      | ("kafka_source_log_level", let input: String) =>
        log_level = match input
          | "Fine" => Fine
          | "Info" => Info
          | "Warn" => Warn
          | "Error" => Error
          else
            let l = StringLogger(log_level, out)
            l(Error) and
              l.log(Error, "Error! Invalid kafka_source_log_level: " + input)
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
      let kc = KafkaConfig(logger, "Kafka Wallaroo Source " + topic)

      // add topic config to consumer
      kc.add_topic_config(topic, KafkaConsumeOnly)

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


class val KafkaSourceConfig[In: Any val] is SourceConfig[In]
  let _conf: KafkaConfig val
  let _auth: TCPConnectionAuth
  let _handler: SourceHandler[In] val

  new val create(conf: KafkaConfig val, auth: TCPConnectionAuth,
    handler: SourceHandler[In] val)
  =>
    _handler = handler
    _auth = auth
    _conf = conf

  fun source_listener_builder_builder(): KafkaSourceListenerBuilderBuilder[In]
  =>
    KafkaSourceListenerBuilderBuilder[In](_conf, _auth)

  fun source_builder(app_name: String, name: String):
    KafkaSourceBuilderBuilder[In]
  =>
    KafkaSourceBuilderBuilder[In](app_name, name, _handler)

