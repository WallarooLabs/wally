use "collections"
use "buffy/messages"
use "net"
use "buffy/metrics"
use "sendence/messages"
use "sendence/guid"
use "sendence/epoch"
use "sendence/queue"
use "debug"

trait BasicStep
  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D)
  be add_step_reporter(sr: StepReporter val) => None

trait BasicOutputStep is BasicStep
  be add_output(to: BasicStep tag)

trait BasicStateStep is BasicStep
  be add_shared_state(shared_state: BasicStep tag)

trait ComputeStep[In] is BasicStep

trait OutputStep[Out] is BasicOutputStep

trait ThroughStep[In, Out] is (ComputeStep[In] & OutputStep[Out])

trait ThroughStateStep[In: Any val, Out: Any val, State: Any #read] is (BasicStateStep &
  ThroughStep[In, Out])

trait PartitionAckable
  be ack(partition_id: U64, step_id: U64)

trait StepManaged
  be add_step_manager(step_manager: StepManager)

actor EmptyStep is BasicStep
  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    None

actor Step[In: Any val, Out: Any val] is ThroughStep[In, Out]
  let _f: Computation[In, Out]
  var _output: BasicStep tag = EmptyStep
  var _step_reporter: (StepReporter val | None) = None

  new create(f: Computation[In, Out] iso) =>
    _f = consume f

  be add_step_reporter(sr: StepReporter val) =>
    _step_reporter = sr

  be add_output(to: BasicStep tag) =>
    _output = to

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let input: In =>
      let start_time = Epoch.nanoseconds()
      _output.send[Out](msg_id, source_ts, ingress_ts, _f(input))
      let end_time = Epoch.nanoseconds()
      match _step_reporter
      | let sr: StepReporter val =>
        sr.report(start_time, end_time)
      end
    end

actor MapStep[In: Any val, Out: Any val] is ThroughStep[In, Out]
  let _f: MapComputation[In, Out]
  var _output: BasicStep tag = EmptyStep
  var _step_reporter: (StepReporter val | None) = None

  new create(f: MapComputation[In, Out] iso) =>
    _f = consume f

  be add_step_reporter(sr: StepReporter val) =>
    _step_reporter = sr

  be add_output(to: BasicStep tag) =>
    _output = to

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let input: In =>
      let start_time = Epoch.nanoseconds()
      for res in _f(input).values() do
        _output.send[Out](msg_id, source_ts, ingress_ts, res)
      end
      let end_time = Epoch.nanoseconds()
      match _step_reporter
      | let sr: StepReporter val =>
        sr.report(start_time, end_time)
      end
    end

actor Source[Out: Any val] is ThroughStep[String, Out]
  var _input_parser: Parser[Out] val
  var _output: BasicStep tag = EmptyStep
  var _step_reporter: (StepReporter val | None) = None

  new create(input_parser: Parser[Out] val) =>
    _input_parser = input_parser

  be add_step_reporter(sr: StepReporter val) =>
    _step_reporter = sr

  be add_output(to: BasicStep tag) =>
    _output = to

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let input: String =>
      try
        let start_time = Epoch.nanoseconds()
        match _input_parser(input)
        | let res: Out =>
          _output.send[Out](msg_id, source_ts, ingress_ts, res)
          let end_time = Epoch.nanoseconds()
          match _step_reporter
          | let sr: StepReporter val =>
            sr.report(start_time, end_time)
          end
        end
      else
        @printf[I32]("Could not process incoming Message at source\n".cstring())
      end
    end

actor PassThrough is BasicOutputStep
  var _output: (BasicStep tag | None) = None
  let _initial_queue: Array[(U64, U64, U64, Any val)] =
    Array[(U64, U64, U64, Any val)]

  be add_output(to: BasicStep tag) => _output = to

  be add_output_and_send[D: Any val](to: BasicStep tag) =>
    _output = to
    for msg in _initial_queue.values() do
      match msg._4
      | let data: D =>
        to.send[D](msg._1, msg._2, msg._3, data)
      else
        @printf[I32]("Queued passthrough message of unknown type\n".cstring())
      end
    end
    _initial_queue.clear()

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match _output
    | let s: BasicStep tag => s.send[D](msg_id, source_ts, ingress_ts, msg_data)
    else
      _initial_queue.push((msg_id, source_ts, ingress_ts, msg_data))
    end

actor Sink[In: Any val] is ComputeStep[In]
  let _f: FinalComputation[In]

  new create(f: FinalComputation[In] iso) =>
    _f = consume f

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let input: In =>
      _f(input)
    end

actor Partition[In: Any val, Out: Any val]
  is (ThroughStep[In, Out] & PartitionAckable & StepManaged)
  let _step_builder: BasicStepBuilder val
  let _partition_function: PartitionFunction[In] val
  let _partitions: Map[U64, U64] = Map[U64, U64]
  let _buffers: Map[U64, Array[(U64, U64, U64, In)]] =
    Map[U64, Array[(U64, U64, U64, In)]]
  var _step_manager: (StepManager | None) = None
  var _output: BasicStep tag = EmptyStep
  let _guid_gen: GuidGenerator = GuidGenerator
  let _partition_report_id: U64 = _guid_gen()

  new create(s_builder: BasicStepBuilder val, pf: PartitionFunction[In] val) =>
    _step_builder = s_builder
    _partition_function = pf

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    _send[D](msg_id, source_ts, ingress_ts, msg_data)

  fun ref _send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let input: In =>
      match _step_manager
      | let sm: StepManager tag =>
        let partition_id = _partition_function(input)
        if _partitions.contains(partition_id) then
          try
            let step_id = _partitions(partition_id)
            sm.send[In](step_id, msg_id, source_ts, ingress_ts, input)
          else
            @printf[I32]("Can't forward to chosen partition!\n".cstring())
          end
        else
          try
            if _buffers.contains(partition_id) then
              _buffers(partition_id).push((msg_id, source_ts, ingress_ts, input))
            else
              _buffers(partition_id) = [(msg_id, source_ts, ingress_ts, input)]
            end
            let step_id = _guid_gen()
            sm.add_partition_step_and_ack(step_id, partition_id,
              _partition_report_id, _step_builder, this)
            sm.add_output_to(step_id, _output)
          else
            @printf[I32]("Computation type is invalid!\n".cstring())
          end
        end
      end
    end

  be ack(partition_id: U64, step_id: U64) =>
    _partitions(partition_id) = step_id
    try
      let buffer = _buffers(partition_id)
      for (id, source_ts, ingress_ts, data) in buffer.values() do
        _send[In](id, source_ts, ingress_ts, data)
      end
      buffer.clear()
    else
      @printf[I32]("Partition: buffer flush failed!\n".cstring())
    end

  be add_output(to: BasicStep tag) =>
    _output = to
    for (key, step_id) in _partitions.pairs() do
      match _step_manager
      | let sm: StepManager tag =>
        sm.add_output_to(step_id, _output)
      end
    end

  be add_step_manager(step_manager: StepManager) =>
    _step_manager = step_manager

actor StatePartition[State: Any #read]
  is (BasicStep & PartitionAckable & StepManaged)
  let _step_builder: BasicStepBuilder val
  let _partitions: Map[U64, U64] = Map[U64, U64]
  let _buffers: Map[U64, Array[(U64, U64, U64, StateProcessor[State] val)]] =
    Map[U64, Array[(U64, U64, U64, StateProcessor[State] val)]]
  var _step_manager: (StepManager | None) = None
  let _guid_gen: GuidGenerator = GuidGenerator
  let _partition_report_id: U64 = _guid_gen()
  let _initialization_map: Map[U64, {(): State} val] val
  let _initialize_at_start: Bool

  new create(s_builder: BasicStepBuilder val, init_map: Map[U64, {(): State} val] val,
    init_at_start: Bool) =>
    _step_builder = s_builder
    _initialization_map = init_map
    _initialize_at_start = init_at_start

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    _send[D](msg_id, source_ts, ingress_ts, msg_data)

  fun ref _send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let sp: StateProcessor[State] val =>
      match _step_manager
      | let sm: StepManager tag =>
        let partition_id = sp.partition_id()
        if _partitions.contains(partition_id) then
          try
            let step_id = _partitions(partition_id)
            sm.send[StateProcessor[State] val](step_id, msg_id, source_ts,
              ingress_ts, sp)
          else
            @printf[I32]("Can't forward to chosen partition!\n".cstring())
          end
        else
          try
            if _buffers.contains(partition_id) then
              _buffers(partition_id).push((msg_id, source_ts, ingress_ts, sp))
            else
              _buffers(partition_id) = [(msg_id, source_ts, ingress_ts, sp)]
              let step_id = _guid_gen()
              if _initialization_map.contains(partition_id) then
                sm.add_partition_step_and_ack(step_id, partition_id,
                  _partition_report_id, _step_builder, this)
                sm.add_initial_state[State](step_id,
                  _initialization_map(partition_id))
              else
                sm.add_partition_step_and_ack(step_id, partition_id,
                  _partition_report_id, _step_builder, this)
              end
            end
          else
            @printf[I32]("Computation type is invalid!\n".cstring())
          end
        end
      end
    end

  be ack(partition_id: U64, step_id: U64) =>
    _partitions(partition_id) = step_id
    try
      let buffer = _buffers(partition_id)
      for (id, source_ts, ingress_ts, data) in buffer.values() do
        match data
        | let sp: StateProcessor[State] val =>
          _send[StateProcessor[State] val](id, source_ts, ingress_ts, sp)
        end
      end
      buffer.clear()
    else
      @printf[I32]("Partition: buffer flush failed!\n".cstring())
    end

  be add_step_manager(step_manager: StepManager) =>
    _step_manager = step_manager
    if _initialize_at_start then
      for (partition_id, init) in _initialization_map.pairs() do
        if (not _partitions.contains(partition_id)) and
          (not _buffers.contains(partition_id)) then
          _buffers(partition_id) = Array[(U64, U64, U64,
            StateProcessor[State] val)]
          let step_id = _guid_gen()
          step_manager.add_partition_step_and_ack(step_id, partition_id,
            _partition_report_id, _step_builder, this)
          step_manager.add_initial_state[State](step_id, init)
        end
      end
    end

actor StateStep[In: Any val, Out: Any val, State: Any #read]
  is ThroughStateStep[In, Out, State]
  var _step_reporter: (StepReporter val | None) = None
  var _output: BasicStep tag = EmptyStep
  var _shared_state: BasicStep tag = EmptyStep
  let _state_comp_builder: Computation[In, StateComputation[Out, State] val]
  let _state_id: U64
  let _partition_function: PartitionFunction[In] val

  new create(comp_builder: ComputationBuilder[In,
    StateComputation[Out, State] val] val, state_id: U64,
    pf: PartitionFunction[In] val = lambda(i: In): U64 => 0 end) =>
    _state_comp_builder = comp_builder()
    _state_id = state_id
    _partition_function = pf

  be add_step_reporter(sr: StepReporter val) =>
    _step_reporter = sr

  be add_output(to: BasicStep tag) =>
    _output = to

  be add_shared_state(shared_state: BasicStep tag) =>
    _shared_state = shared_state

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let input: In =>
      let start_time = Epoch.nanoseconds()
      let sc: StateComputation[Out, State] val = _state_comp_builder(input)
      let sc_wrapper = StateComputationWrapper[In, Out, State](sc,
        _output, _partition_function(input))
      _shared_state.send[StateProcessor[State] val](msg_id, source_ts,
        ingress_ts, sc_wrapper)
      let end_time = Epoch.nanoseconds()
      match _step_reporter
      | let sr: StepReporter val =>
        sr.report(start_time, end_time)
      end
    end

actor SharedStateStep[State: Any #read]
  is BasicStep
  var _step_reporter: (StepReporter val | None) = None
  var _state: State

  new create(state_initializer: StateInitializer[State] val) =>
    _state = state_initializer()

  be add_step_reporter(sr: StepReporter val) =>
    _step_reporter = sr

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let sp: StateProcessor[State] val =>
      let start_time = Epoch.nanoseconds()
      _state = sp(msg_id, source_ts, ingress_ts, _state)
      let end_time = Epoch.nanoseconds()
      match _step_reporter
      | let sr: StepReporter val =>
        sr.report(start_time, end_time)
      end
    end

  be update_state(state: {(): State} val) =>
    _state = state()

actor ExternalConnection[In: Any val] is ComputeStep[In]
  let _array_stringify: ArrayStringify[In] val
  let _conns: Array[TCPConnection]
  let _metrics_collector: MetricsCollector tag
  let _pipeline_name: String
  embed _write_buffer: WriteBuffer = WriteBuffer

  new create(array_stringify: ArrayStringify[In] val, conns: Array[TCPConnection] iso =
    recover Array[TCPConnection] end, m_coll: MetricsCollector tag,
    pipeline_name: String) =>
    _array_stringify = array_stringify
    _conns = consume conns
    _metrics_collector = m_coll
    _pipeline_name = pipeline_name

  be add_conn(conn: TCPConnection) =>
    _conns.push(conn)

  be send[D: Any val](msg_id: U64, source_ts: U64, ingress_ts: U64,
    msg_data: D) =>
    match msg_data
    | let input: In =>
      try
        let out = _array_stringify(input)
        ifdef debug then
          Debug.out(
            match out
            | let s: String =>
              ">>>>" + s + "<<<<"
            | let arr: Array[String] val =>
              ">>>>" + ",".join(arr) + "<<<<"
            end
          )
        end
        let tcp_msg = FallorMsgEncoder(out, _write_buffer)
        for conn in _conns.values() do
          conn.writev(tcp_msg)
        end
        let now = Epoch.nanoseconds()
        _metrics_collector.report_boundary_metrics(BoundaryTypes.source_sink(),
          msg_id, source_ts, now, _pipeline_name)
        _metrics_collector.report_boundary_metrics(
          BoundaryTypes.ingress_egress(), msg_id, ingress_ts, now)
      end
    end

interface StateInitializer[State: Any #read]
  fun apply(): State
