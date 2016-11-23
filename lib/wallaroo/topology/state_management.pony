use "assert"
use "collections"
use "buffered"

trait StateChange[State: Any #read]
  fun name(): String val
  fun id(): U64
  fun apply(state: State)
  fun write_log_entry(out_writer: Writer)
  fun ref read_log_entry(in_reader: Reader) ?

class EmptyStateChange[State: Any #read] is StateChange[State]
  fun name(): String val => ""
  fun id(): U64 => 0
  fun apply(state: State) => None
  fun write_log_entry(out_writer: Writer) => None
  fun ref read_log_entry(in_reader: Reader) => None

trait StateChangeBuilder[State: Any #read]
  fun apply(id: U64): StateChange[State]

class StateChangeRepository[State: Any #read]
  let _state_changes: Array[StateChange[State] ref] ref
  let _named_lookup: Map[String val, U64] ref

  new create() =>
    _state_changes = Array[StateChange[State] ref]
    _named_lookup = Map[String val, U64]

  fun ref make_and_register(scb: StateChangeBuilder[State] val): U64 =>
    let idx = _state_changes.size().u64()
    let sc = scb(idx)
    _named_lookup.update(sc.name(),idx)
    _state_changes.push(sc)
    idx

  fun ref apply(index: U64): StateChange[State] ref ? =>
    _state_changes(index.usize())

  fun ref lookup_by_name(name: String): StateChange[State] ref ? =>
    ifdef debug then
      try
        Assert(_named_lookup.contains(name),
        "Invariant violated: _named_lookup.contains(name) for name: " + name)
      else
        //TODO: how do we bail out here?
        None
      end
    end

    _state_changes(_named_lookup(name).usize())

  fun size() : USize =>
    _state_changes.size()

  fun contains(name: String): Bool =>
    _named_lookup.contains(name)
