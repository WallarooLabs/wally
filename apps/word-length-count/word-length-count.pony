use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "buffy/topology/external"

actor Main
  new create(env: Env) =>
    // TODO: how are buffy topologies built? are they built on every single
    // node even if some of the steps will only be in some of the nodes?
    // what happens when the external process is only on some of the nodes?
    // atm, all nodes need to be identical
    try
      // TODO: current buffy (buffy, not giles/dagon) does not support 
      // configuration of its steps via config files or some other form, 
      // so doing it this way, not sure whether this is a good idea
      let jvmConfig = JVMConfigBuilder.from_ini(env, 
        "./apps/word-length-count/word-length-count-java.ini"
        ).asExternalProcessConfig()
      let topology = recover val
        Topology
          .new_pipeline[String, String](P, S, recover [0] end, "word-length-count")
          .to_external[String](WordLengthCountProcessBuilder(jvmConfig))
          .build()
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
  let _config: ExternalProcessConfig val 

  new iso create(config': ExternalProcessConfig val) =>
    _config = config'

  fun config(): ExternalProcessConfig val => _config
  fun codec(): ExternalProcessCodec[String, String] val => CsvCodec
  fun length_encoder(): ByteLengthEncoder val => JavaLengthEncoder
  fun name(): String val => "word-length-counter"
