use "collections"
use "files"
use "net"
use "time"
use "wallaroo_labs/bytes"
use "wallaroo_labs/math"
use "wallaroo_labs/options"

actor Main
  let _env: Env
  var _required_args_are_present: Bool = true

  new create(env: Env) =>
    _env = env

    try
      var h_arg: (Array[String] | None) = None
      var f_arg: (String | None) = None
      var b_arg: (USize | None) = None
      var m_arg: (USize | None) = None

      var options = Options(env.args)

      options
        .add("host", "h", StringArgument)
        .add("file", "f", StringArgument)
        .add("batch-size", "b", I64Argument)
        .add("msg-size", "m", I64Argument)

      for option in options do
        match option
        | ("host", let arg: String) =>
          h_arg = arg.split(":")
        | ("file", let arg: String) =>
          f_arg = arg
        | ("batch-size", let arg: I64) =>
          b_arg = arg.usize()
        | ("msg-size", let arg: I64) =>
          m_arg = arg.usize()
        end
      end

      if h_arg is None then
        _args_error("Must supply required '--host' argument")
      else
        if (h_arg as Array[String]).size() != 2 then
          _args_error("'--host' argument should be in format: '127.0.0.1:7669")
        end
      end

      match f_arg
      | let fp: String =>
        let path = FilePath(env.root as AmbientAuth, fp)?
        if not path.exists() then
          _args_error("Error opening file " + fp)
        end
      else
        _args_error("Must supply required '--file' argument")
      end

      if b_arg is None then
        _args_error("Must supply required '--batch-size' argument")
      end

      if m_arg is None then
        _args_error("Must supply required '--msg-size' argument")
      end

      if _required_args_are_present then
        let batch_size = b_arg as USize
        let msg_size = m_arg as USize
        let host = h_arg as Array[String]
        let file_path = FilePath(env.root as AmbientAuth, f_arg as String)?

        let batches = match OpenFile(file_path)
        | let f: File =>
          if (f.size() % msg_size) != 0 then
            _startup_error("Files doesn't contain " + msg_size.string() + " byte messages")
          end

          ChunkData(f, msg_size, batch_size)
        else
          _startup_error("Unable to open data file for reading")
          recover val Array[Array[U8] val] end
        end

        let notifier = Notifier(env.err)

        try
          let tcp = TCPConnection(env.root as AmbientAuth,
            consume notifier,
            host(0)?,
            host(1)?)

          let sender = Sender(tcp, batches, env.err)
          sender.start()
        else
          env.err.print("Unable to send")
        end
      end
    else
      env.err.print("Unknown error occurred")
    end

  fun ref _args_error(msg: String) =>
    _env.err.print(msg)
    _required_args_are_present = false

  fun _startup_error(msg: String) =>
    _env.err.print(msg)

   @exit[None](U8(1))

actor Sender
  let _err: OutStream
  let _tcp: TCPConnection
  let _data_chunks: Array[Array[U8] val] val
  var _data_chunk_index: USize = 0
  let _timers: Timers = Timers

  new create(tcp: TCPConnection,
    data_chunks: Array[Array[U8] val] val,
    err: OutStream)
  =>
    _tcp = tcp
    _data_chunks = data_chunks
    _err = err

  be start() =>
    let t = Timer(TriggerSend(this), 0, 500)
    _timers(consume t)

  be send() =>
    try
      let chunk = _data_chunks(_data_chunk_index)?
      _tcp.write(chunk)
      _data_chunk_index = _data_chunk_index + 1
      if _data_chunk_index >= _data_chunks.size() then
        _data_chunk_index = 0
      end
    else
      _err.print("Bug in sender")
    end

class Notifier is TCPConnectionNotify
  let _err: OutStream

  new iso create(err: OutStream) =>
    _err = err

  fun ref connect_failed(conn: TCPConnection ref) =>
    _err.print("Unable to connect")

primitive ChunkData
  fun apply(f: File,
    msg_size: USize,
    batch_size: USize) : Array[Array[U8] val]  val
  =>
    let bytes_in_file = f.size()
    let msgs_in_file = bytes_in_file / msg_size
    let file_data: Array[U8] val = f.read(bytes_in_file)

    let bytes_needed_for_a_batch = msg_size * batch_size

    let batches_needed = Math.lcm(msgs_in_file, batch_size) / batch_size
    let bytes_in_batch = batch_size * msg_size
    let memory_needed =  batches_needed * bytes_in_batch
    let file_copies_needed = memory_needed / bytes_in_file

    var for_chunking = recover iso Array[U8] end
    for_chunking.reserve(memory_needed)

    for i in Range(0, file_copies_needed) do
      for_chunking.append(file_data)
    end

    for_chunking.truncate(memory_needed)

    let b = recover iso Array[Array[U8] val] end

    for i in Range(0, batches_needed) do
      (let c, for_chunking) = (consume for_chunking).chop(bytes_in_batch)
      b.push(consume c)
    end

    b

class TriggerSend is TimerNotify
  let _sender: Sender

  new iso create(sender: Sender) =>
    _sender = sender

  fun ref apply(timer: Timer, count: U64): Bool =>
    _sender.send()
    true
