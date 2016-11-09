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
    ((Out | None), (StateChange[State] ref | None))

  fun name(): String

  fun state_change_builders(): Array[StateChangeBuilder[State] val] val

trait StateProcessor[State: Any #read] is BasicComputation
  fun name(): String
  // Return a tuple containing a Bool indicating whether the message was 
  // finished processing here and the state change (or None if there was
  // no state change).
  // TODO: solve the situation where Out is None and we
  // still want the message passed along
  fun apply(state: State, sc_repo: StateChangeRepository[State],
    metric_name: String, source_ts: U64,
    producer: (CreditFlowProducer ref | None),
    // incoming envelope
    i_origin: Origin tag, i_msg_uid: U128, 
    i_frac_ids': (Array[U64] val | None), i_seq_id: U64, i_route_id: U64,
    // outgoing envelope
    o_origin: Origin tag, o_msg_uid: U128, o_frac_ids: (Array[U64] val | None),
    o_seq_id: U64): (Bool, (StateChange[State] ref | None))

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
    producer: (CreditFlowProducer ref | None),
    // incoming envelope
    i_origin: Origin tag, i_msg_uid: U128, 
    i_frac_ids: (Array[U64] val | None), i_seq_id: U64, i_route_id: U64,
    // outgoing envelope
    o_origin: Origin tag, o_msg_uid: U128, o_frac_ids: (Array[U64] val | None),
    o_seq_id: U64): (Bool, (StateChange[State] ref | None))
  =>
    let result = _state_comp(_input, sc_repo, state)

    // It matters that the None check comes first, since Out could be
    // type None if you always filter/end processing there
    match result
    | (None, _) => (true, result._2) // This must come first
    | (let output: Out, _) =>
      let is_finished = _router.route[Out](metric_name, source_ts, output, 
        producer,
        // incoming envelope
        i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id,
        // outgoing envelope
        o_origin, o_msg_uid, o_frac_ids, o_seq_id)
      (is_finished, result._2)
    else
      (true, result._2)
    end

  fun name(): String => _state_comp.name()

interface BasicComputationBuilder
  fun apply(): BasicComputation val

interface ComputationBuilder[In: Any val, Out: Any val]
  fun apply(): Computation[In, Out] val

interface StateBuilder[State: Any #read]
  fun apply(): State
  fun name(): String
