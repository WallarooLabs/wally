use "buffered"
use "buffy/topology"
use "files"
use "net"
use "ini"

class JavaLengthEncoder is ByteLengthEncoder
  let java_integer_size_in_bytes: USize = 4

  fun apply(msg: Array[U8] val): Array[ByteSeq] val =>
    Writer.create()
    .i32_be(msg.size().i32())
    .write(msg)
    .done()

  fun msg_header_length(): USize val =>
    java_integer_size_in_bytes

  fun msg_size(header: Array[U8] val): USize val ? =>
    Reader.create().append(header).i32_be().usize()

primitive JVMConfigBuilder
  fun class_from_ini(env: Env,
    ini_file: String): ExternalProcessConfig val ? =>
    """
    Reads the following fields from an INI under [java] section:
      - java_home (required)
      - main_class (required)
      - class_path (required) that has main_class in it
      - java_opts (optional)
    """
    let file = File(FilePath(env.root as AmbientAuth, ini_file))
    let sections = IniParse(file.lines())

    let java_home: String = sections("java")("java_home")
    let main_class: String = sections("java")("main_class")
    let classpath: String = sections("java")("class_path")
    let java_opts: (String | None) =
      try sections("java")("java_opts") else None end

    ExternalProcessConfig(
      _java_process_path(env, java_home),
      _java_process_args(where
        main_class = main_class,
        java_opts = java_opts),
      _environment_variables(java_home, classpath))

  fun uberjar_from_ini(env: Env,
    ini_file: String): ExternalProcessConfig val ? =>
    """
    Reads the following fields from an INI under [java] section:
      - java_home (required)
      - uber_jar (required) for all inclusive jar with manifest w/ main class
      - class_path (optional) for additional library
      - java_opts (optional)
    """
    let file = File(FilePath(env.root as AmbientAuth, ini_file))
    let sections = IniParse(file.lines())

    let java_home: String = sections("java")("java_home")
    let uber_jar: (String | None) = sections("java")("uber_jar")
    let classpath: (String | None) =
      try sections("java")("class_path") else None end
    let java_opts: (String | None) =
      try sections("java")("java_opts") else None end

    ExternalProcessConfig(
      _java_process_path(env, java_home),
      _java_process_args(where
        uber_jar = uber_jar,
        java_opts = java_opts),
      _environment_variables(java_home, classpath))


  fun _java_process_path(env: Env, java_home: String): FilePath ? =>
    FilePath(env.root as AmbientAuth, java_home + "/bin/java")

  fun _java_process_args(main_class: (String | None) = None,
                         java_opts: (String | None) = None,
                         uber_jar: (String | None) = None):
  Array[String] val =>
    let args: Array[String] iso = recover Array[String]() end
    args.push("java")
    match java_opts
    | let value: String => args.push(value)
    end
    match main_class
    | let value: String => args.push(value)
    end
    match uber_jar
    | let value: String =>
      args.push("-jar")
      args.push(value)
    end
    consume args

  fun _environment_variables(java_home: String,
                             classpath: (String | None)): Array[String] val =>
    let vars: Array[String] iso = recover Array[String]() end
    vars.push("JAVA_HOME=" + java_home)
    vars.push("PATH=" + java_home + "/bin")
    match classpath
    | let value: String =>
      vars.push("CLASSPATH=" + value)
    end
    consume vars
