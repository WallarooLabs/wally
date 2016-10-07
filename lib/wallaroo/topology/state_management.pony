use "collections"

trait StateChange[State: Any #read]
  fun name(): String val
  fun id(): U64
  fun apply(state: State)
  fun to_log_entry(): Array[U8] val
  fun read_log_entry(entry: Array[U8] val)

class StateChangeRepository[State: Any #read]
  let _state_changes: Array[StateChange[State] ref] ref
  let _named_lookup: Map[String val, U64] ref

  new create() =>
    _state_changes = Array[StateChange[State] ref]
    _named_lookup = Map[String val, U64]

  fun ref register(sc: StateChange[State]): U64 =>
    let idx = _state_changes.size().u64()
    _named_lookup.update(sc.name(),idx)
    _state_changes.push(sc)
    idx

  fun apply(index: U64): StateChange[State] box ? =>
    _state_changes(index.usize())

  fun lookup_by_name(name: String): StateChange[State] box ? =>
    _state_changes(_named_lookup(name).usize())

  fun size() : USize =>
    _state_changes.size()
