use "collections"
use "buffy/messages"
use "net"

trait BasicStep
  be apply(input: StepMessage val)

trait OutputStep
  be add_output(to: BasicStep tag)

trait ComputeStep[In: OSCEncodable] is BasicStep

trait ThroughStep[In: OSCEncodable val,
                  Out: OSCEncodable val] is (OutputStep & ComputeStep[In])

actor Step[In: OSCEncodable val, Out: OSCEncodable val] is ThroughStep[In, Out]
  let _f: Computation[In, Out]
  var _output: (BasicStep tag | None) = None

  new create(f: Computation[In, Out] iso) =>
    _f = consume f

  be add_output(to: BasicStep tag) =>
    _output = to

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      match _output
      | let o: BasicStep tag =>
        o(_f(m))
      end
    end

actor Source[Out: OSCEncodable val] is ThroughStep[String, Out]
  var _input_parser: Parser[Out] val
  var _output: (BasicStep tag | None) = None

  new create(input_parser: Parser[Out] val) =>
    _input_parser = input_parser

  be add_output(to: BasicStep tag) =>
    _output = to

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[String] val =>
      try
        let new_msg: Message[Out] val = Message[Out](m.id, _input_parser(m.data))
        match _output
        | let o: BasicStep tag =>
          o(new_msg)
        end
      else
        @printf[String]("Could not process incoming Message at source\n".cstring())
      end
    end

actor Sink[In: OSCEncodable val] is ComputeStep[In]
  let _f: FinalComputation[In]

  new create(f: FinalComputation[In] iso) =>
    _f = consume f

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      _f(m)
    end

actor Partition[In: OSCEncodable val, Out: OSCEncodable val] is ThroughStep[In, Out]
  let _step_builder: StepBuilder[In, Out] val
  let _partition_function: PartitionFunction[In] val
  let _partitions: Map[I32, BasicStep tag] = Map[I32, BasicStep tag]
  var _output: (BasicStep tag | None) = None

  new create(s_builder: StepBuilder[In, Out] val, pf: PartitionFunction[In] val) =>
    _step_builder = s_builder
    _partition_function = pf

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      let partition_id = _partition_function(m.data)
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
            match _output
            | let o: BasicStep tag =>
              t.add_output(o)
            end
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
          match _output
          | let o: BasicStep tag =>
            t.add_output(o)
          end
        else
          @printf[String]("Partition not a ThroughStep!\n".cstring())
        end
      else
          @printf[String]("Couldn't find partition when trying to add output!\n".cstring())
      end
    end

actor StateStep[In: OSCEncodable val, Out: OSCEncodable val,
  State: Any #read] is ThroughStep[In, Out]
  let _state_computation: StateComputation[In, Out, State]
  var _output: (BasicStep tag | None) = None
  let _state: State

  new create(state_initializer: {(): State} val,
    state_computation: StateComputation[In, Out, State] iso) =>
    _state = state_initializer()
    _state_computation = consume state_computation

  be add_output(to: BasicStep tag) =>
    _output = to

  be apply(input: StepMessage val) =>
    match input
    | let i: Message[In] val =>
      let r = _state_computation(_state, i)
      match _output
        | let o: BasicStep tag => o(r)
      end
    end

interface TagBuilder
  fun apply(): Any tag

trait OutputStepBuilder[Out: OSCEncodable val]

trait ThroughStepBuilder[In: OSCEncodable val, Out: OSCEncodable val]
  is OutputStepBuilder[Out]
  fun apply(): ThroughStep[In, Out] tag

class SourceBuilder[Out: OSCEncodable val]
  is ThroughStepBuilder[String, Out]
  let _parser: Parser[Out] val

  new val create(p: Parser[Out] val) =>
    _parser = p

  fun apply(): ThroughStep[String, Out] tag =>
    Source[Out](_parser)

class StepBuilder[In: OSCEncodable val, Out: OSCEncodable val]
  is ThroughStepBuilder[In, Out]
  let _computation_builder: ComputationBuilder[In, Out] val

  new val create(c: ComputationBuilder[In, Out] val) =>
    _computation_builder = c

  fun apply(): ThroughStep[In, Out] tag =>
    Step[In, Out](_computation_builder())

class PartitionBuilder[In: OSCEncodable val, Out: OSCEncodable val]
  is ThroughStepBuilder[In, Out]
  let _step_builder: StepBuilder[In, Out] val
  let _partition_function: PartitionFunction[In] val

  new val create(c: ComputationBuilder[In, Out] val, pf: PartitionFunction[In] val) =>
    _step_builder = StepBuilder[In, Out](c)
    _partition_function = pf

  fun apply(): ThroughStep[In, Out] tag =>
    Partition[In, Out](_step_builder, _partition_function)

class StateStepBuilder[In: OSCEncodable val, Out: OSCEncodable val, State: Any #read]
  is ThroughStepBuilder[In, Out]
  let _state_computation_builder: StateComputationBuilder[In, Out, State] val
  let _state_initializer: {(): State} val

  new val create(s_builder: StateComputationBuilder[In, Out, State] val,
    s_initializer: {(): State} val) =>
    _state_computation_builder = s_builder
    _state_initializer = s_initializer

  fun apply(): ThroughStep[In, Out] tag =>
    StateStep[In, Out, State](_state_initializer, _state_computation_builder())

class ExternalConnectionBuilder[In: OSCEncodable val]
  let _stringify: Stringify[In] val

  new val create(stringify: Stringify[In] val) =>
    _stringify = stringify

  fun apply(conn: TCPConnection): ExternalConnection[In] =>
    ExternalConnection[In](_stringify, conn)
