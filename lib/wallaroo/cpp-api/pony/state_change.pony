use "buffered"
use "wallaroo/topology"

use @w_state_change_get_name[Pointer[U8]](state_change: StateChangeP)
use @w_state_change_get_id[U64](state_change: StateChangeP)
use @w_state_change_apply[None](state_change: StateChangeP, state: StateP)
use @w_state_change_get_log_entry_size[USize](state_change: StateChangeP)
use @w_state_change_to_log_entry[None](state_change: StateChangeP, bytes: Pointer[U8] tag)
use @w_state_change_get_log_entry_size_header_size[USize](state_change: StateChangeP)
use @w_state_change_read_log_entry_size_header[USize](state_change: StateChangeP, bytes: Pointer[U8] tag)
use @w_state_change_read_log_entry[Bool](state_change: StateChangeP, bytes: Pointer[U8] tag)

type StateChangeP is ManagedObjectP

class CPPStateChange is StateChange[CPPState]
  let _state_change: CPPManagedObject val
  let _name: String

  new create(state_change: CPPManagedObject val) =>
    _state_change = state_change
    _name = recover String.from_cstring(@w_state_change_get_name(_state_change.obj())) end

  fun name(): String =>
    _name

  fun id(): U64 =>
    @w_state_change_get_id(_state_change.obj())

  fun apply(state: CPPState) =>
    @w_state_change_apply(_state_change.obj(), state.obj())

  fun write_log_entry(out_writer: Writer) =>
    let sz = @w_state_change_get_log_entry_size(_state_change.obj())
    let bytes: Array[U8] val = recover
      let b = Array[U8](sz)
      @w_state_change_to_log_entry(_state_change.obj(), b.cpointer())
      b
    end
    out_writer.write(consume bytes)

  fun read_log_entry(in_reader: Reader) ? =>
    let header_size = @w_state_change_get_log_entry_size_header_size(_state_change.obj())
    let sz = if header_size > 0 then
      // variable size log entry
      @w_state_change_read_log_entry_size_header(_state_change.obj(), in_reader.block(header_size).cpointer())
    else
      // fixed size log entry
      @w_state_change_get_log_entry_size(_state_change.obj())
    end
    let bytes = in_reader.block(sz)
    if @w_state_change_read_log_entry(_state_change.obj(), bytes.cpointer()) == false then
      error
    end

  fun obj(): StateChangeP =>
    _state_change.obj()