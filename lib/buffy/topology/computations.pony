use "buffy/messages"
use "collections"

interface Computation[In, Out]
  fun ref apply(input: In): Out
  fun name(): String

interface MapComputation[In, Out]
  fun ref apply(input: In): Seq[Out]
  fun name(): String

interface FinalComputation[In]
  fun ref apply(input: In)

interface PartitionFunction[In]
  fun apply(input: In): U64

interface StateComputation[In,
  Out, State: Any #read]

  fun ref apply(state: State, input: In): Out

interface ComputationBuilder[In, Out]
  fun apply(): Computation[In, Out] iso^

interface MapComputationBuilder[In, Out]
  fun apply(): MapComputation[In, Out] iso^

interface StateComputationBuilder[In, Out,
  State: Any #read]
  fun apply(): StateComputation[In, Out, State] iso^

interface Parser[Out]
  fun apply(s: String): Out ?

interface Stringify[In]
  fun apply(i: In): String ?
