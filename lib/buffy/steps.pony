use "collections"
use "buffy/messages"

interface ComputeStep[In: OSCEncodable val]
  be apply(input: Message[In] val)

interface ThroughStep[In: OSCEncodable val,
                      Out: OSCEncodable val] is ComputeStep[In]
  be add_output(to: ComputeStep[Out] tag)

actor Step[In: OSCEncodable val, Out: OSCEncodable val] is ThroughStep[In, Out]
  let _f: Computation[In, Out]
  var _output: (ComputeStep[Out] tag | None) = None

  new create(f: Computation[In, Out] iso) =>
    _f = consume f

  be add_output(to: ComputeStep[Out] tag) =>
    _output = to

  be apply(input: Message[In] val) =>
    match _output
    | let c: ComputeStep[Out] tag => c(_f(input))
    end

actor Sink[In: OSCEncodable val] is ComputeStep[In]
  let _f: FinalComputation[In]

  new create(f: FinalComputation[In] iso) =>
    _f = consume f

  be apply(input: Message[In] val) =>
    _f(input)

actor Partition[In: OSCEncodable val, Out: OSCEncodable val] is ThroughStep[In, Out]
  let _computation_type: String
  let _step_builder: StepBuilder val
  let _partition_function: PartitionFunction[In] val
  let _partitions: Map[I32, Any tag] = Map[I32, Any tag]
  var _output: (ComputeStep[Out] tag | None) = None

  new create(c_type: String val, pf: PartitionFunction[In] val,
    sb: StepBuilder val) =>
    _computation_type = c_type
    _partition_function = pf
    _step_builder = sb

  be apply(input: Message[In] val) =>
    let partition_id = _partition_function(input.data)
    if _partitions.contains(partition_id) then
      try
        match _partitions(partition_id)
        | let c: ComputeStep[In] tag => c(input)
        else
          @printf[String]("Partition not a ComputeStep!".cstring())
        end
      end
    else
      try
        let comp = _step_builder(_computation_type)
        _partitions(partition_id) = comp
        match comp
        | let t: ThroughStep[In, Out] tag =>
          match _output
          | let o: ComputeStep[Out] tag => t.add_output(o)
          end
          t(input)
        end
      else
        @printf[String]("Computation type is invalid!".cstring())
      end
    end

  be add_output(to: ComputeStep[Out] tag) =>
    _output = to
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
