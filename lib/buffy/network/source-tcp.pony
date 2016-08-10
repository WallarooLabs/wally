use "net"
use "collections"
use "buffy/metrics"
use "buffy/messages"
use "sendence/messages"
use "sendence/bytes"
use "sendence/guid"
use "sendence/epoch"
use "../topology"
use "random"
use "debug"

class SourceNotifier[In: Any val] is TCPListenNotify
  let _env: Env
  let _host: String
  let _service: String
  let _source_id: U64
  let _coordinator: Coordinator
  let _parser: Parser[In] val
  let _local_step_builder: LocalStepBuilder val
  let _output: BasicStep tag
  let _shared_state_step: (BasicSharedStateStep tag | None)
  let _metrics_collector: MetricsCollector tag

  new iso create(env: Env, source_host: String,
    source_service: String, source_id: U64, 
    coordinator: Coordinator, parser: Parser[In] val, output: BasicStep tag,
    shared_state_step: (BasicSharedStateStep tag | None) = None,
    local_step_builder: LocalStepBuilder val = PassThroughStepBuilder[In, In],
    metrics_collector: MetricsCollector tag)
  =>
    _env = env
    _host = source_host
    _service = source_service
    _source_id = source_id
    _coordinator = coordinator
    _parser = parser
    _shared_state_step = shared_state_step
    _local_step_builder = local_step_builder
    _output = output
    _metrics_collector = metrics_collector

  fun ref listening(listen: TCPListener ref) =>
    _env.out.print("Source " + _source_id.string() + ": listening on "
      + _host + ":" + _service)

  fun ref not_listening(listen: TCPListener ref) =>
    _env.out.print("Source " + _source_id.string() + ": couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref) : TCPConnectionNotify iso^ =>
    SourceConnectNotify[In](_env, _source_id, _coordinator,
      _parser, _output, _shared_state_step, _local_step_builder,
      _metrics_collector)

class SourceConnectNotify[In: Any val] is TCPConnectionNotify
  let _guid_gen: GuidGenerator = GuidGenerator
  let _env: Env
  let _source_id: U64
  let _coordinator: Coordinator
  let _parser: Parser[In] val
  let _local_step: BasicOutputLocalStep
  var _header: Bool = true
  var _msg_count: USize = 0
  let _metrics_collector: MetricsCollector tag

  new iso create(env: Env, source_id: U64, coordinator: Coordinator,
    parser: Parser[In] val, output: BasicStep tag,
    shared_state_step: (BasicSharedStateStep tag | None),
    local_step_builder: LocalStepBuilder val,
    metrics_collector: MetricsCollector tag)
  =>
    _env = env
    _source_id = source_id
    _coordinator = coordinator
    _parser = parser
    _local_step = local_step_builder.local()
    _metrics_collector = metrics_collector
    _local_step.add_output(output)

    let step_id = _guid_gen()
    let step_builder_name = local_step_builder.name()
    _local_step.add_step_reporter(MetricsReporter(step_id, step_builder_name,
      "source-sink", _metrics_collector))
    match _local_step
    | let state_step: BasicStateLocalStep =>
      match shared_state_step
      | let ss: BasicSharedStateStep tag =>
        state_step.add_shared_state(ss)
      end
    end

  fun ref accepted(conn: TCPConnection ref) =>
    ifdef debug then
      try
        (let host, _) = conn.remote_address().name()
        Debug.out("SourceConnectNotify.accepted() " + host)
      end
    end

    conn.expect(4)
    _coordinator.add_connection(conn)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        conn.expect(expect)
        _header = false
      else
        _env.err.print("Error reading header from external source")
      end
    else

      let now = Epoch.nanoseconds()
      let input_raw = String.from_array(consume data)
      try
        match _parser(input_raw)
        | let input: In =>
          _local_step.send[In](_guid_gen(), now, now, input)
        else
          _env.out.print("Error parsing input at source")
        end
      else
        _env.out.print("Error parsing input at source")
      end

      conn.expect(4)
      _header = true
      _msg_count = _msg_count + 1
      if _msg_count >= 5 then
        _msg_count = 0
        return false
      end
    end
    true

  fun ref connected(conn: TCPConnection ref) =>
    _env.out.print("Source " + _source_id.string() + ": connected.")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("Source " + _source_id.string() + ": connection failed.")

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("Source " + _source_id.string() + ": server closed")
