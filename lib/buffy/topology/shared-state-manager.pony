use "collections"
use "time"
use "random"
use "sendence/guid"

actor SharedStateManager
  let _shared_state: Map[U64, U64] = Map[U64, U64]
  var _step_manager: (StepManager tag | None) = None
  let _guid_gen: GuidGenerator = GuidGenerator

  be add_step_manager(step_manager: StepManager tag) =>
    _step_manager = step_manager

  be add_step_id(state_id: U64, state_step_id: U64) =>
    if not _shared_state.contains(state_id) then
      _shared_state(state_id) = state_step_id
    end

  be connect_to_state(state_id: U64, state_step: BasicStateStep tag) =>
    try
      let shared_state_step_id = _shared_state(state_id)
      match _step_manager
      | let sm: StepManager tag =>
        sm.connect_to_state(shared_state_step_id, state_step)
      end
    else
      @printf[None](("Couldn't connect to state id " + state_id.string() + "\n").cstring())
    end
