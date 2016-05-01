use "buffy/messages"

interface Computation[In: OSCEncodable, Out: OSCEncodable]
  fun ref apply(input: Message[In] val): Message[Out] val^

interface FinalComputation[In: OSCEncodable]
  fun ref apply(input: Message[In] val)

interface PartitionFunction[In: OSCEncodable]
  fun apply(input: In): I32