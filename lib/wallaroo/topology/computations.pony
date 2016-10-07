use "buffered"

trait BasicComputation
  fun name(): String

interface Computation[In: Any val, Out: Any val] is BasicComputation
  fun apply(input: In): (Out | None)
  fun name(): String

interface StateComputation[In: Any val, Out: Any val, State: Any #read] is BasicComputation
  // Return a Bool indicating whether the message was finished processing here
  // Return false to indicate the message was sent on to the next step.
  fun apply(input: In, state: State): (Out | None)
  fun name(): String

trait StateProcessor[State: Any #read] is BasicComputation
  fun name(): String
  // Return a Bool indicating whether the message was finished processing here
  // Return false to indicate the message was sent on to the next step.
  fun apply(state: State, metric_name: String, source_ts: U64): Bool
  fun find_partition(finder: PartitionFinder val): Router val

class StateComputationWrapper[In: Any val, Out: Any val, State: Any #read]
  let _state_comp: StateComputation[In, Out, State] val
  let _input: In
  let _router: Router val

  new val create(input: In, state_comp: StateComputation[In, Out, State] val,
    router: Router val) =>
    _state_comp = state_comp
    _input = input
    _router = router

  fun apply(state: State, metric_name: String, source_ts: U64): Bool =>
    match _state_comp(_input, state)
    | None => true
    | let output: Out =>
      _router.route[Out](metric_name, source_ts, output)
      false
    else
      true
    end

  fun name(): String => _state_comp.name()

  fun find_partition(finder: PartitionFinder val): Router val =>
    finder.find[In](_input)

interface BasicComputationBuilder
  fun apply(): BasicComputation val

interface ComputationBuilder[In: Any val, Out: Any val]
  fun apply(): Computation[In, Out] val

interface StateBuilder[State: Any #read]
  fun apply(): State
  fun name(): String


