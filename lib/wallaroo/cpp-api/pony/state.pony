type StateP is ManagedObjectP

class CPPState
  let _state: CPPManagedObject

  new create(state: CPPManagedObject) =>
    _state = state

  fun obj(): StateP =>
    _state.obj()