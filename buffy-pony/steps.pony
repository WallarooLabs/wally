use "collections"

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
