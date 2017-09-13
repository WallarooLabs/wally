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

use "wallaroo/core/state"

// these are included because of issue #814
use "serialise"
use "wallaroo/core/fail"

type StateP is Pointer[U8] val

class CPPState is State
  var _state: StateP

  new create(state: StateP) =>
    _state = state

  fun obj(): StateP =>
    _state

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_state)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_state, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _state = recover @w_user_serializable_deserialize(bytes) end

  fun _final() =>
    @w_managed_object_delete(_state)
