use "collections"
use "buffy/messages"
use "net"

interface BasicStep
  be apply(input: StepMessage val)

interface OutputStep
  be add_output(to: BasicStep tag)

trait ComputeStep[In: OSCEncodable] is BasicStep

trait ThroughStep[In: OSCEncodable val,
                  Out: OSCEncodable val] is (OutputStep & ComputeStep[In])

actor Step[In: OSCEncodable val, Out: OSCEncodable val] is ThroughStep[In, Out]
  let _f: Computation[In, Out]
  var _output: (ComputeStep[Out] tag | None) = None

  new create(f: Computation[In, Out] iso) =>
    _f = consume f

  be add_output(to: BasicStep tag) =>
    match to
    | let c: ComputeStep[Out] tag =>
      _output = c
    end

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      match _output
      | let c: ComputeStep[In] tag => c(_f(m))
      end
    end

actor Source[Out: OSCEncodable val] is ThroughStep[String, Out]
  var _input_parser: Parser[Out] val
  var _output: (ComputeStep[Out] tag | None) = None

  new create(input_parser: Parser[Out] val) =>
    _input_parser = input_parser

  be add_output(to: BasicStep tag) =>
    match to
    | let c: ComputeStep[Out] tag =>
      _output = c
    else
      @printf[String]("Could not add output".cstring())
    end

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[String] val =>
      match _output
      | let c: ComputeStep[Out] tag =>
        try
          let new_msg: Message[Out] val = Message[Out](m.id,
            _input_parser(m.data))
          c(new_msg)
        end
      else
        @printf[String]("Could not process incoming Message".cstring())
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
  let _computation_builder: ComputationBuilder[In, Out] val
  let _partition_function: PartitionFunction[In] val
  let _partitions: Map[I32, Any tag] = Map[I32, Any tag]
  var _output: (ComputeStep[Out] tag | None) = None

  new create(c_builder: ComputationBuilder[In, Out] val, pf: PartitionFunction[In] val) =>
    _computation_builder = c_builder
    _partition_function = pf

  be apply(input: StepMessage val) =>
    match input
    | let m: Message[In] val =>
      let partition_id = _partition_function(m.data)
      if _partitions.contains(partition_id) then
        try
          match _partitions(partition_id)
          | let c: ComputeStep[In] tag => c(m)
          else
            @printf[String]("Partition not a ComputeStep!".cstring())
          end
        end
      else
        try
          _partitions(partition_id) = _computation_builder()
          match _partitions(partition_id)
          | let t: ThroughStep[In, Out] tag =>
            match _output
            | let o: ComputeStep[Out] tag => t.add_output(o)
            end
            t(m)
          end
        else
          @printf[String]("Computation type is invalid!".cstring())
        end
      end
    end

  be add_output(to: BasicStep tag) =>
    match to
    | let o: ComputeStep[Out] tag =>
      _output = o
      for key in _partitions.keys() do
        try
          match _partitions(key)
          | let t: ThroughStep[In, Out] tag => t.add_output(to)
          else
            @printf[String]("Partition not a ThroughStep!".cstring())
          end
        else
            @printf[String]("Couldn't find partition when trying to add output!".cstring())
        end
      end
    end

/*
// commented out until ponylang/ponyc issue #807 is fixed
actor State[In: OSCEncodable val, Out: OSCEncodable val, DataStructure: Any] is ThroughStep[In, Out]
  let _f: StateComputation[In, Out, DataStructure]
  var _output: (ComputeStep[Out] tag | None) = None
  let _state: Map[I32, I32]

  new create(state: DataStructure iso, f: StateComputation[In, Out, DataStructure] iso) =>
    _state = consume state
    _f = consume f

  be add_output(to: ComputeStep[Out] tag) =>
    _output = to

  be apply(input: Message[In] val) =>
    let r = _f(_state, input)
    match _output
      | let c: ComputeStep[Out] tag => c(r)
    end
*/

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
  let _computation_builder: ComputationBuilder[In, Out] val
  let _partition_function: PartitionFunction[In] val

  new val create(c: ComputationBuilder[In, Out] val, pf: PartitionFunction[In] val) =>
    _computation_builder = c
    _partition_function = pf

  fun apply(): ThroughStep[In, Out] tag =>
    Partition[In, Out](_computation_builder, _partition_function)

class ExternalConnectionBuilder[In: OSCEncodable val]
  let _stringify: Stringify[In] val

  new val create(stringify: Stringify[In] val) =>
    _stringify = stringify

  fun apply(conn: TCPConnection): ExternalConnection[In] =>
    ExternalConnection[In](_stringify, conn)
