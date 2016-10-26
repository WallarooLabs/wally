use "collections"
use "process"
use "files"
use "sendence/epoch"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "debug"

class ExternalProcessConfig
  let path: FilePath
  let args: Array[String] val
  let environment_variables: Array[String] val

  new val create(path': FilePath,
                 args': Array[String] val,
                 environment_variables': Array[String] val) =>
    path = path'
    args = args'
    environment_variables = environment_variables'

trait ExternalProcessCodec[In: Any val, Out: Any val]
  """
  A codec that defines the contract for messages going to and from the
  external process.
  """
  fun encode(msg: ExternalMessage[In] val): Array[U8] val ?
    """
    Encode a message into an array of U8's to be sent the external process.
    """

  fun decode(data: Array[U8] val): ExternalMessage[Out] val ?
    """
    Takes an array of U8's returned as a response from the external process
    and decode it into a message.
    """

  fun shutdown_signal(): Array[U8] val
    """
    Message sent to external process to signal it to shut itself down
    gracefully
    """

trait ByteLengthEncoder
  """
  Allows us to tell where one message ends and the next begins on a stream
  of bytes (like stdin/stdout/etc)
  """
  fun apply(msg: Array[U8] val): Array[ByteSeq] val
    """
    Encode a payload with its length in bytes in a fixed size header known
    to both sender and receiver
    """

  fun msg_header_length(): USize val
    """
    Length of a message header of message encoded in this format
    """

  fun msg_size(header: Array[U8] val): USize val ?
    """
    Given a header, determine the size of the message to follow in bytes
    """

actor ExternalProcessStep[In: Any val, Out: Any val] is ThroughStep[In, Out]
  let _auth: ProcessMonitorAuth
  let _config: ExternalProcessConfig val
  let _codec: ExternalProcessCodec[In, Out] val
  let _length_encoder: ByteLengthEncoder val

  var _output: BasicStep tag = EmptyStep
  var _step_reporter: (MetricsReporter ref | None) = None
  var _process_monitor: (ProcessMonitor | None) = None
  var _completed: Bool = false

  new create(auth: ProcessMonitorAuth,
    config: ExternalProcessConfig val,
    codec: ExternalProcessCodec[In, Out] val,
    length_encoder: ByteLengthEncoder val) =>
    _auth = auth
    _config = config
    _codec = codec
    _length_encoder = length_encoder
    _process_monitor = _start_process(auth, config, length_encoder)

  be add_step_reporter(sr: MetricsReporter iso) =>
    _step_reporter = consume sr

  be add_output(to: BasicStep tag) =>
    _output = to

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    _restart_process_if_necessary()
    _execute_with_process(lambda(p: ProcessMonitor)(msg_id, source_ts,
      ingress_ts, msg_data, codec=_codec, length_encoder=_length_encoder) =>
      match msg_data
      | let d: In =>
        let start_time = Epoch.milliseconds()
        let ext_msg = ExternalMessage[In](msg_id, source_ts,
          ingress_ts, start_time, d)
        try
          let encoded_msg_data = codec.encode(ext_msg)
          let length_encoded_msg = length_encoder(encoded_msg_data)
          p.writev(length_encoded_msg)
        end
      end
    end,
    "External process not running. Not sent")

  // TODO: our steps do not have init/shutdown hooks so write external
  // processes are not notified of termination but they find out by way of
  // accident when stdin is closed and they notify us with false exit errors
  // because of this. instead we should have a hook within buffy to have each
  // steps terminate() be called before the topology is shutdown.
  be terminate() =>
    _execute_with_process(lambda(p: ProcessMonitor)(codec=_codec, length_encoder=_length_encoder) =>
      let poison_pill = codec.shutdown_signal()
      let encoded_pill = length_encoder(poison_pill)
      p.writev(encoded_pill)
      // TODO: get this working, can't figure out how to access 'p' from within
      // Timers(
      //   Timer(
      //     object is TimerNotify
      //       fun ref apply(timer: Timer, count: U64): Bool =>
      //         p.dispose()
      //         false /* cancel after running once */
      //     end,
      //     10000000000 /* 10 seconds */
      //   )
      // )
    end,
    "External process is already not running. Nothing to terminate")
    _completed = true
    _process_monitor = None

  be _message_completed(msg_undecoded: Array[U8] val) =>
    try
      let ext_msg: ExternalMessage[Out] val = _codec.decode(msg_undecoded)
      _output.send[Out](ext_msg.id(), ext_msg.source_ts(),
        ext_msg.last_ingress_ts(), ext_msg.data())
      match _step_reporter
      | let sr: MetricsReporter ref =>
        let end_time: U64 = Epoch.milliseconds()
        sr.report(ext_msg.sent_to_external_ts(), end_time)
      end
    end

  be _mark_process_exited() =>
    _process_monitor = None

  be _mark_completed() =>
    _completed = true

  fun _execute_with_process(f: {(ProcessMonitor)}, error_msg: String) =>
    match _process_monitor
    | let pm: ProcessMonitor =>
      f(pm)
    else
      @printf[I32](error_msg.cstring())
    end

  fun tag _start_process(auth: ProcessMonitorAuth,
    config: ExternalProcessConfig val,
    length_encoder: ByteLengthEncoder val): (ProcessMonitor | None)
  =>
    let notifier: ProcessNotify iso = ExternalProcessNotifier[In, Out](this, length_encoder)
    ProcessMonitor(auth,
      consume notifier,
      config.path,
      config.args,
      config.environment_variables)

  fun ref _restart_process_if_necessary() =>
    if _completed then return end
    match _process_monitor
    | None =>
      _log("Attempting to restart external process")
      _process_monitor = _start_process(_auth, _config, _length_encoder)
      // TODO: how do we know when external process is ready to respond to msgs
      // Should we add some kind of handshaking (ping/pong)?
    end

  fun _log(s: String) =>
    // TODO: replace w/ logger
    @printf[I32]((s + "\n").cstring())

class ExternalProcessNotifier[In: Any val, Out: Any val] is ProcessNotify
  let _step: ExternalProcessStep[In, Out] tag
  let _length_encoder: ByteLengthEncoder val

  // TODO: should a Reader be used instead? why?
  var _buffer: Array[U8] iso = recover Array[U8] end
  var _msg_size: USize = 0

  new iso create(step: ExternalProcessStep[In, Out] tag,
    length_encoder: ByteLengthEncoder val) =>
    _step = step
    _length_encoder = length_encoder

  fun ref stdout(process: ProcessMonitor ref, data: Array[U8] iso) =>
    _buffer.append(consume data)

    let msg_header_size: USize = _length_encoder.msg_header_length()

    var expect_size: USize = 0
    if (_msg_size > 0) then
      expect_size = _msg_size
    else
      expect_size = msg_header_size
    end

    while (_buffer.size() >= expect_size) do
      if _msg_size == 0 then
        let header: Array[U8] val = _extract(0, msg_header_size)
        try
          _msg_size = _length_encoder.msg_size(header)
          expect_size = _msg_size
        else
          _log("Couldn't extract payload size from header")
          _msg_size = 0
          expect_size = msg_header_size
        end
      else
        let msg_undecoded: Array[U8] val = _extract(0, _msg_size)
        _step._message_completed(msg_undecoded)
        _msg_size = 0
        expect_size = msg_header_size
      end
    end

  fun ref _extract(start: USize, length: USize): Array[U8] val =>
    var holder: Array[U8] iso = recover Array[U8].create(length) end
    var i: USize = start
    // TODO: is there a better way to extract a subset of elements from a
    // Array[] iso/ref as a Array[] val than copying elements one at a time?
    repeat
      try
        holder.push(_buffer(i))
      else
        _log("Couldn't lookup element from array")
      end
      i = i + 1
    until i == length end
    if length < (_buffer.size() - 1) then
      _buffer.remove(start, length)
    else
      _buffer.clear()
    end
    consume holder

  fun ref stderr(process: ProcessMonitor ref, data: Array[U8] iso) =>
    _log(String.from_array(consume data))

  fun ref failed(process: ProcessMonitor ref, err: ProcessError) =>
    if not is_recoverable(err) then
      _step._mark_completed()
    end

  fun is_recoverable(err: ProcessError val): Bool =>
    match err
    | ExecveError   => _log("ProcessError: ExecveError")
    | PipeError     => _log("ProcessError: PipeError")
    | ForkError     => _log("ProcessError: ForkError")
    | WaitpidError  => _log("ProcessError: WaitpidError")
    | WriteError    => _log("ProcessError: WriteError")
    | KillError     => _log("ProcessError: KillError")
    | Unsupported   => _log("ProcessError: Unsupported")
    else
      _log("Unknown ProcessError!")
    end
    // TODO: this is used to decide whether the external process should be
    // automatically restarted or whether this is a irrecoverable failure.
    // not sure whether it should be done here by inspecting ProcessError
    // or in the dispose method below by inspecting the process exit code or
    // both.
    true

  fun dispose(process: ProcessMonitor ref, child_exit_code: I32) =>
    let code: I32 = consume child_exit_code
    _log("External process exited:" + code.string())
    _step._mark_process_exited()

  fun _log(s: String) =>
    // TODO: replace w/ logger
    @printf[I32]((s + "\n").cstring())
