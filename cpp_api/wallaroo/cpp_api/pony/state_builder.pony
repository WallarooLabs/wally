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

use @w_state_builder_get_name[Pointer[U8]](sb: StateBuilderP)
use @w_state_builder_build_state[StateP](sb: StateBuilderP)

class CPPStateBuilder
  var _state_builder: StateBuilderP

  new create(state_builder: StateBuilderP) =>
    _state_builder = state_builder

  fun name(): String =>
    String.from_cstring(@w_state_builder_get_name(_state_builder)).clone()

  fun apply(): CPPState =>
    CPPState(@w_state_builder_build_state(_state_builder))

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_state_builder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_state_builder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _state_builder = recover
      @w_user_serializable_deserialize(bytes)
    end

  fun _final() =>
    @w_managed_object_delete(_state_builder)
