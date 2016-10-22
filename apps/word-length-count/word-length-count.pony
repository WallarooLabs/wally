use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "buffy/topology/external"
use "process"

actor Main
  """
  Instructions for running:
  1. Update config: ./apps/word-length-count/word-length-count-java.ini
    to match your environment
  2. Build pony: make build-buffy-components && make build-word-length-count && make build-wesley
  3. Build java: cd ./external-lang-api/java/ && mvn clean install && cd - & cd ./apps/word-length-count/ && mvn clean package && cd -
  4. Run: make dagon-word-length-count
  """
  new create(env: Env) =>
    try
      let jvmConfig = JVMConfigBuilder.uberjar_from_ini(env,
        "./apps/word-length-count/word-length-count-java.ini"
        )
      let topology = recover val
        Topology
          .new_pipeline[String, String](P, "word-length-count")
            .to_external[String](WordLengthCountProcessBuilder(env.auth as AmbientAuth, jvmConfig))
            .to_simple_sink(S, recover [0] end)
      end
      Startup(env, topology, 1)
    else
      env.out.print("Couldn't build topology. Possibly word-length-count-java.ini is misconfigured or missing")
    end

primitive P
  fun apply(s: String): String =>
    s

primitive S
  fun apply(input: String): String =>
    input

class CsvCodec is ExternalProcessCodec[String val, String val]
  """
  This can eventually be switched to Avro or Json or whatever we prefer.
  """
  var _delimiter: String

  new val create(delimiter: String = ",") =>
    _delimiter = delimiter

  fun encode(m: ExternalMessage[String] val): Array[U8] val ? =>
    if (m.data().contains(_delimiter)) then
      _log("Unable to encode message, contains delimiter in it")
      error
    end

    let msg = m.id().string() + _delimiter +
      m.source_ts().string() + _delimiter +
      m.last_ingress_ts().string() + _delimiter +
      m.sent_to_external_ts().string() + _delimiter +
      m.data()

    msg.array()

  fun decode(data: Array[U8 val] val): ExternalMessage[String] val ? =>
    let parts = String.from_array(data).split(_delimiter)
    if (parts.size() != 5) then
      _log("Unable to decode msg: does not contain all parts")
      error
    end
    ExternalMessage[String].create(parts(0).u64(),
      parts(1).u64(),
      parts(2).u64(),
      parts(3).u64(),
      parts(4)
    )

  fun _log(s: String) =>
    // TODO: replace w/ logger
    @printf[I32]((s + "\n").cstring())


  fun shutdown_signal(): Array[U8] val =>
    "POISON".array()

class WordLengthCountProcessBuilder is ExternalProcessBuilder[String, String]
  let _auth: ProcessMonitorAuth
  let _config: ExternalProcessConfig val

  new iso create(auth': ProcessMonitorAuth,
    config': ExternalProcessConfig val)
  =>
    _auth = auth'
    _config = config'

  fun auth(): ProcessMonitorAuth => _auth
  fun config(): ExternalProcessConfig val => _config
  fun codec(): ExternalProcessCodec[String, String] val => CsvCodec
  fun length_encoder(): ByteLengthEncoder val => JavaLengthEncoder
  fun name(): String val => "word-length-counter"
