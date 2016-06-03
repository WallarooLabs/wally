use "collections"
use "buffy/messages"
use "net"
use "buffy/metrics"
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

actor Partition[In: Any val, Out: Any val] is ThroughStep[In, Out]
  let _step_builder: BasicStepBuilder val
  let _partition_function: PartitionFunction[In] val
  let _partitions: Map[U64, BasicStep tag] = Map[U64, BasicStep tag]
  var _output: BasicStep tag = EmptyStep

  new create(s_builder: BasicStepBuilder val, pf: PartitionFunction[In] val) =>
    _step_builder = s_builder
    _partition_function = pf

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      let partition_id = _partition_function(m.data())
      if _partitions.contains(partition_id) then
        try
          _partitions(partition_id)(m)
        else
          @printf[String]("Can't forward to chosen partition!\n".cstring())
        end
      else
        try
          _partitions(partition_id) = _step_builder()
          match _partitions(partition_id)
          | let t: ThroughStep[In, Out] tag =>
            t.add_output(_output)
            t(m)
          end
        else
          @printf[String]("Computation type is invalid!\n".cstring())
        end
      end
    end

  be add_output(to: BasicStep tag) =>
    _output = to
    for key in _partitions.keys() do
      try
        match _partitions(key)
        | let t: ThroughStep[In, Out] tag =>
          t.add_output(_output)
        else
          @printf[String]("Partition not a ThroughStep!\n".cstring())
        end
      else
          @printf[String]("Couldn't find partition when trying to add output!\n".cstring())
      end
    end

actor StateStep[In: Any val, Payload: Any val, State: Any #read]
  is ThroughStateStep[In, Payload, State]
  var _step_reporter: (StepReporter val | None) = None
  var _output: BasicStep tag = EmptyStep
  var _shared_state: BasicStep tag = EmptyStep
  let _state_comp_builder: Computation[In, StateComputation[Payload, State] val]
  let _state_id: U64

  new create(comp_builder: ComputationBuilder[In,
    StateComputation[Payload, State] val] val, state_id: U64) =>
    _state_comp_builder = comp_builder()
    _state_id = state_id

  be add_step_reporter(sr: StepReporter val) =>
    _step_reporter = sr

  be add_output(to: BasicStep tag) =>
    _output = to

  be add_shared_state(shared_state: BasicStep tag) =>
    _shared_state = shared_state

  be apply(input: StepMessage val) =>
    @printf[None]("StateStep: apply called!\n".cstring())
    match input
    | let m: Message[In] val =>
      @printf[None]("StateStep: Message[StateComputation[Out, State]] matched!\n".cstring())
      let start_time = Time.millis()
      let sc: StateComputation[Payload, State] val = _state_comp_builder(m.data())
      let message_wrapper = DefaultMessageWrapper[Payload](m.id(), m.source_ts(),
        m.last_ingress_ts())
      let sc_wrapper = StateComputationWrapper[Payload, State](sc,
        message_wrapper, _output)
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
    @printf[None]("SharedStateStep: apply called!\n".cstring())
    match input
    | let m: Message[StateProcessor[State] val] val =>
      @printf[None]("SharedStateStep: Message[StateProcessor[State]] matched!\n".cstring())
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
