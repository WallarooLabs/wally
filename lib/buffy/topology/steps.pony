use "collections"
use "buffy/messages"
use "net"
use "buffy/metrics"
use "sendence/guid"
use "time"

trait BasicStep
  be apply(input: StepMessage val)
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
  be apply(input: StepMessage val) => None

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

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      let start_time = Time.millis()
      let output_msg =
        Message[Out](m.id(), m.source_ts(), m.last_ingress_ts(), _f(m.data()))
      _output(output_msg)
      let end_time = Time.millis()
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

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      let start_time = Time.millis()
      for res in _f(m.data()).values() do
        let output_msg =
          Message[Out](m.id(), m.source_ts(), m.last_ingress_ts(), res)
        _output(output_msg)
      end
      let end_time = Time.millis()
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

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[String] val =>
      try
        let start_time = Time.millis()
        match _input_parser(m.data())
        | let res: Out =>
          let output_msg: Message[Out] val =
            Message[Out](m.id(), m.source_ts(), m.last_ingress_ts(), res)
          _output(output_msg)
          let end_time = Time.millis()
          match _step_reporter
          | let sr: StepReporter val =>
            sr.report(start_time, end_time)
          end
        end
      else
        @printf[String]("Could not process incoming Message at source\n".cstring())
      end
    end

actor Sink[In: Any val] is ComputeStep[In]
  let _f: FinalComputation[In]

  new create(f: FinalComputation[In] iso) =>
    _f = consume f

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      _f(m.data())
    end

actor Partition[In: Any val, Out: Any val]
  is (ThroughStep[In, Out] & PartitionAckable & StepManaged)
  let _step_builder: BasicStepBuilder val
  let _partition_function: PartitionFunction[In] val
  let _partitions: Map[U64, U64] = Map[U64, U64]
  let _buffers: Map[U64, Array[StepMessage val]] = Map[U64, Array[StepMessage val]]
  var _step_manager: (StepManager | None) = None
  var _output: BasicStep tag = EmptyStep
  let _guid_gen: GuidGenerator = GuidGenerator

  new create(s_builder: BasicStepBuilder val, pf: PartitionFunction[In] val) =>
    _step_builder = s_builder
    _partition_function = pf

  be apply(input: StepMessage val) => _apply(input)

  fun ref _apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      match _step_manager
      | let sm: StepManager tag =>
        let partition_id = _partition_function(m.data())
        if _partitions.contains(partition_id) then
          try
            let step_id = _partitions(partition_id)
            sm(step_id, input)
          else
            @printf[String]("Can't forward to chosen partition!\n".cstring())
          end
        else
          try
            if _buffers.contains(partition_id) then
              _buffers(partition_id).push(input)
            else
              _buffers(partition_id) = [input]
            end
            let step_id = _guid_gen()
            sm.add_partition_step_and_ack(step_id, partition_id,
              _step_builder, this)
            sm.add_output_to(step_id, _output)
          else
            @printf[String]("Computation type is invalid!\n".cstring())
          end
        end
      end
    end

  be ack(partition_id: U64, step_id: U64) =>
    _partitions(partition_id) = step_id
    try
      let buffer = _buffers(partition_id)
      for msg in buffer.values() do
        _apply(msg)
      end
      buffer.clear()
    else
      @printf[None]("Partition: buffer flush failed!\n".cstring())
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
  let _buffers: Map[U64, Array[StepMessage val]] = Map[U64, Array[StepMessage val]]
  var _step_manager: (StepManager | None) = None
  let _guid_gen: GuidGenerator = GuidGenerator

  new create(s_builder: BasicStepBuilder val) =>
    _step_builder = s_builder

  be apply(input: StepMessage val) => _apply(input)

  fun ref _apply(input: StepMessage val) =>
    match input
    | let m: Message[StateProcessor[State] val] val =>
      match _step_manager
      | let sm: StepManager tag =>
        let partition_id = m.data().partition_id()
        if _partitions.contains(partition_id) then
          try
            let step_id = _partitions(partition_id)
            sm(step_id, input)
          else
            @printf[String]("Can't forward to chosen partition!\n".cstring())
          end
        else
          try
            if _buffers.contains(partition_id) then
              _buffers(partition_id).push(input)
            else
              _buffers(partition_id) = [input]
            end
            let step_id = _guid_gen()
            sm.add_partition_step_and_ack(step_id, partition_id,
              _step_builder, this)
          else
            @printf[String]("Computation type is invalid!\n".cstring())
          end
        end
      end
    end

  be ack(partition_id: U64, step_id: U64) =>
    _partitions(partition_id) = step_id
    try
      let buffer = _buffers(partition_id)
      for msg in buffer.values() do
        _apply(msg)
      end
      buffer.clear()
    else
      @printf[None]("Partition: buffer flush failed!\n".cstring())
    end

  be add_step_manager(step_manager: StepManager) =>
    _step_manager = step_manager

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

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      let start_time = Time.millis()
      let sc: StateComputation[Out, State] val = _state_comp_builder(m.data())
      let message_wrapper = DefaultMessageWrapper[Out](m.id(), m.source_ts(),
        m.last_ingress_ts())
      let sc_wrapper = StateComputationWrapper[In, Out, State](sc,
        message_wrapper, _output, _partition_function(m.data()))
      let output_msg = Message[StateProcessor[State] val](m.id(),
        m.source_ts(), m.last_ingress_ts(), sc_wrapper)
      _shared_state(output_msg)
      let end_time = Time.millis()
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

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[StateProcessor[State] val] val =>
      let sp: StateProcessor[State] val = m.data()
      let start_time = Time.millis()
      _state = sp(_state)
      let end_time = Time.millis()
      match _step_reporter
      | let sr: StepReporter val =>
        sr.report(start_time, end_time)
      end
    end

actor ExternalConnection[In: Any val] is ComputeStep[In]
  let _stringify: {(In): String ?} val
  let _conns: Array[TCPConnection]
  let _metrics_collector: MetricsCollector tag

  new create(stringify: {(In): String ?} val, conns: Array[TCPConnection] iso =
    recover Array[TCPConnection] end, m_coll: MetricsCollector tag) =>
    _stringify = stringify
    _conns = consume conns
    _metrics_collector = m_coll

  be add_conn(conn: TCPConnection) =>
    _conns.push(conn)

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      try
        let str = _stringify(m.data())
        @printf[String]((">>>>" + str + "<<<<\n").cstring())
        let tcp_msg = ExternalMsgEncoder.data(str)
        for conn in _conns.values() do
          conn.write(tcp_msg)
        end
        _metrics_collector.report_boundary_metrics(BoundaryTypes.source_sink(),
          m.id(), m.source_ts(), Time.millis())
      end
    end

interface StateInitializer[State: Any #read]
  fun apply(): State
