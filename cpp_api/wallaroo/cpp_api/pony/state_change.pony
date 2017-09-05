/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "buffered"
use "wallaroo/state"

use @w_state_change_get_name[Pointer[U8]](state_change: StateChangeP)
use @w_state_change_get_id[U64](state_change: StateChangeP)
use @w_state_change_apply[None](state_change: StateChangeP, state: StateP)
use @w_state_change_get_log_entry_size[USize](state_change: StateChangeP)
use @w_state_change_to_log_entry[None](state_change: StateChangeP,
  bytes: Pointer[U8] tag)
use @w_state_change_get_log_entry_size_header_size[USize]
  (state_change: StateChangeP)
use @w_state_change_read_log_entry_size_header[USize]
  (state_change: StateChangeP, bytes: Pointer[U8] tag)
use @w_state_change_read_log_entry[Bool](state_change: StateChangeP,
  bytes: Pointer[U8] tag)

type StateChangeP is Pointer[U8] val

class CPPStateChange is StateChange[CPPState]
  let _state_change: StateChangeP

  new create(state_change: StateChangeP) =>
    _state_change = state_change

  fun name(): String =>
    recover String.from_cstring(@w_state_change_get_name(_state_change)) end

  fun id(): U64 =>
    @w_state_change_get_id(_state_change)

  fun apply(state: CPPState) =>
    @w_state_change_apply(_state_change, state.obj())

  fun write_log_entry(out_writer: Writer) =>
    let sz = @w_state_change_get_log_entry_size(_state_change)
    let bytes: Array[U8] val = recover
      let b = Array[U8](sz)
      @w_state_change_to_log_entry(_state_change, b.cpointer())
      b
    end
    out_writer.write(consume bytes)

  fun read_log_entry(in_reader: Reader) ? =>
    let header_size =
      @w_state_change_get_log_entry_size_header_size(_state_change)

    let sz = if header_size > 0 then
      // variable size log entry
      @w_state_change_read_log_entry_size_header(_state_change,
        in_reader.block(header_size).cpointer())
    else
      // fixed size log entry
      @w_state_change_get_log_entry_size(_state_change)
    end

    let bytes = in_reader.block(sz)

    if @w_state_change_read_log_entry(_state_change, bytes.cpointer()) == false
      then
      error
    end

  fun obj(): StateChangeP =>
    _state_change

  fun _final() =>
    @w_managed_object_delete(_state_change)
