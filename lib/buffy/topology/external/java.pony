use "buffy/topology"
use "files"
use "net"
use "ini"

class JavaLengthEncoder is ByteLengthEncoder
  let java_integer_size_in_bytes: USize = 4

  fun apply(msg: Array[U8] val): Array[ByteSeq] val =>
    WriteBuffer.create()
    .i32_be(msg.size().i32())
    .write(msg)
    .done()

  fun msg_header_length(): USize val =>
    java_integer_size_in_bytes

  fun msg_size(header: Array[U8] val): USize val ? =>
    ReadBuffer.create().append(header).i32_be().usize()

class JVMConfigBuilder
  """
  Currently supports use of a single java main class as an external process,
  along with all its dependencies provided via a specifiable classpath. 

  TODO: Should also support jar files, including uberjars w/ their own 
  manifests so the main class need not be specified.
  """

  let _env: Env
  let _main_class: String
  let _classpath: String
  let _java_home: String
  let _java_opts: String

  new val create(env: Env,
                 main_class: String val, 
                 classpath: String val,
                 java_home: String val, 
                 java_opts: String val) =>
    _env = env
    _main_class = main_class
    _classpath = classpath
    _java_home = java_home
    _java_opts = java_opts

  new val from_ini(env: Env,
                   ini_file': String) ? =>
    _env = env

    let ini_file = File(FilePath(env.root as AmbientAuth, ini_file'))
    let sections = IniParse(ini_file.lines())

    _main_class = sections("java")("main_class")
    _classpath = sections("java")("class_path")
    _java_home = sections("java")("java_home")
    _java_opts = sections("java")("java_opts")

    env.out.print("Using: ")
    env.out.print(" java_home: " + _java_home)
    env.out.print(" class_path: " + _classpath)
    env.out.print(" main_class: " + _main_class)
    env.out.print(" java_opts: " + _java_opts)

  fun asExternalProcessConfig(): ExternalProcessConfig val ? =>
    ExternalProcessConfig(_java_process_path(), 
      _java_process_args(), 
      _environment_variables())

  fun _java_process_path(): FilePath ? =>
    FilePath(_env.root as AmbientAuth, _java_home + "/bin/java")

  fun _java_process_args(): Array[String] val =>
    let args: Array[String] iso = recover Array[String](3) end
    args.push("java")
    args.push(_java_opts)
    args.push(_main_class)
    consume args

  fun _environment_variables(): Array[String] val => 
    let vars: Array[String] iso = recover Array[String](3) end
    vars.push("JAVA_HOME=" + _java_home)
    vars.push("PATH=" + _java_home + "/bin")
    vars.push("CLASSPATH=" + _classpath)
    consume vars