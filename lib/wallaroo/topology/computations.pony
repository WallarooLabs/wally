use "buffered"
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
    omni_router: OmniRouter val, metric_name: String, source_ts: U64,
    producer: Producer ref,
    i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: SeqId):
      (Bool, (StateChange[State] ref | None))

trait InputWrapper
  fun input(): Any val

class StateComputationWrapper[In: Any val, Out: Any val, State: Any #read]
  is (StateProcessor[State] & InputWrapper)
  let _state_comp: StateComputation[In, Out, State] val
  let _input: In
  let _target_id: U128

  new val create(input': In, state_comp: StateComputation[In, Out, State] val,
    target_id: U128) =>
    _state_comp = state_comp
    _input = input'
    _target_id = target_id

  fun input(): Any val => _input

  fun apply(state: State, sc_repo: StateChangeRepository[State],
    omni_router: OmniRouter val, metric_name: String, source_ts: U64,
    producer: Producer ref,
    i_origin: Producer, i_msg_uid: U128,
    i_frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId):
      (Bool, (StateChange[State] ref | None))
  =>
    let result = _state_comp(_input, sc_repo, state)

    // It matters that the None check comes first, since Out could be
    // type None if you always filter/end processing there
    match result
    | (None, _) => (true, result._2) // This must come first
    | (let output: Out, _) =>
      let is_finished = omni_router.route_with_target_id[Out](_target_id,
        metric_name, source_ts, output, producer,
        // incoming envelope
        i_origin, i_msg_uid, i_frac_ids, i_seq_id, i_route_id)

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
