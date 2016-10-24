use "buffered"
use "wallaroo/messages"
use "wallaroo/backpressure"

trait BasicComputation
  fun name(): String

interface Computation[In: Any val, Out: Any val] is BasicComputation
  fun apply(input: In): (Out | None)
  fun name(): String

interface StateComputation[In: Any val, Out: Any val, State: Any #read] is BasicComputation
  // Return a tuple containing the result of the computation (which is None
  // if there is no value to forward) and a StateChange if there was one (or
  // None to indicate no state change). 
  fun apply(input: In, sc_repo: StateChangeRepository[State], state: State):
    ((Out | None), (StateChange[State] val | None))

  fun name(): String

trait StateProcessor[State: Any #read] is BasicComputation
  fun name(): String
  // Return a tuple containing a Bool indicating whether the message was 
  // finished processing here and the state change (or None if there was
  // no state change).
  // TODO: StateChange should be a reusable ref
  fun apply(state: State, sc_repo: StateChangeRepository[State],
    metric_name: String, source_ts: U64,
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None)): 
      (Bool, (StateChange[State] val | None))
  fun find_partition(finder: PartitionFinder val): Router val

class StateComputationWrapper[In: Any val, Out: Any val, State: Any #read]
  is StateProcessor[State]
  let _state_comp: StateComputation[In, Out, State] val
  let _input: In
  let _router: Router val

  new val create(input: In, state_comp: StateComputation[In, Out, State] val,
    router: Router val) =>
    _state_comp = state_comp
    _input = input
    _router = router

  fun apply(state: State, sc_repo: StateChangeRepository[State],
    metric_name: String, source_ts: U64, 
    incoming_envelope: MsgEnvelope box, outgoing_envelope: MsgEnvelope,
    producer: (CreditFlowProducer ref | None)): 
      (Bool, (StateChange[State] val | None))
  =>
    let result = _state_comp(_input, sc_repo, state)

    match result
    | (None, _) => (true, result._2)
    | (let output: Out, _) =>
      let is_finished = _router.route[Out](metric_name, source_ts, output, 
        incoming_envelope, outgoing_envelope, producer)
      (is_finished, result._2)
    else
      (true, result._2)
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
