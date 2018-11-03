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

use "assert"
use "buffered"
use "collections"
use "serialise"
use "wallaroo"
use "wallaroo/core/invariant"


trait StateChange[S: State ref]
  fun name(): String val
  fun id(): U64
  fun apply(state: S)
  fun write_log_entry(out_writer: Writer)
  fun ref read_log_entry(in_reader: Reader) ?

primitive DirectStateChange

class EmptyStateChange[S: State ref] is StateChange[S]
  fun name(): String val => ""
  fun id(): U64 => 0
  fun apply(state: S) => None
  fun write_log_entry(out_writer: Writer) => None
  fun ref read_log_entry(in_reader: Reader) => None

trait val StateChangeBuilder[S: State ref]
  fun apply(id: U64): StateChange[S]

class StateChangeRepository[S: State ref]
  let _state_changes: Array[StateChange[S] ref] ref
  let _named_lookup: Map[String val, U64] ref

  new create() =>
    _state_changes = Array[StateChange[S] ref]
    _named_lookup = Map[String val, U64]

  fun ref make_and_register(scb: StateChangeBuilder[S]): U64 =>
    let idx = _state_changes.size().u64()
    let sc = scb(idx)
    _named_lookup.update(sc.name(),idx)
    _state_changes.push(sc)
    idx

  fun ref apply(index: U64): StateChange[S] ref ? =>
    _state_changes(index.usize())?

  fun ref lookup_by_name(name: String): StateChange[S] ref ? =>
    _state_changes(_named_lookup(name)?.usize())?

  fun size() : USize =>
    _state_changes.size()

  fun contains(name: String): Bool =>
    _named_lookup.contains(name)
