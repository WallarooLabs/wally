use "buffy/messages"
use "collections"

interface Computation[In: OSCEncodable, Out: OSCEncodable]
  fun ref apply(input: In): Out

interface FinalComputation[In: OSCEncodable]
  fun ref apply(input: In)

interface PartitionFunction[In: OSCEncodable]
  fun apply(input: In): I32

interface StateComputation[In: OSCEncodable,
  Out: OSCEncodable, State: Any #read]

  fun ref apply(state: State, input: In): Out

interface ComputationBuilder[In: OSCEncodable, Out: OSCEncodable]
  fun apply(): Computation[In, Out] iso^

interface StateComputationBuilder[In: OSCEncodable, Out: OSCEncodable,
  State: Any #read]
  fun apply(): StateComputation[In, Out, State] iso^

interface Parser[Out: OSCEncodable]
  fun apply(s: String): Out ?

interface Stringify[In: OSCEncodable]
  fun apply(i: In): String ?
