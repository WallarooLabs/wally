use "buffered"

interface Computation[In: Any val, Out: Any val]
  fun apply(input: In): (Out | None)
  fun name(): String

interface StateComputation[In: Any val, State: Any #read]
  fun apply(input: In, state: State, wb: (Writer | None)): (None | StateChange[State])
  fun name(): String

interface StateProcessor[State: Any #read]
  fun name(): String
  fun apply(state: State, wb: (Writer | None)): (None | StateChange[State])

class StateComputationWrapper[In: Any val, State: Any #read]
  let _state_comp: StateComputation[In, State] val
  let _input: In

  new val create(input: In, state_comp: StateComputation[In, State] val) =>
    _state_comp = state_comp
    _input = input

  fun apply(state: State, wb: (Writer | None)): None =>
    _state_comp(_input, state, wb)

  fun name(): String => _state_comp.name()
