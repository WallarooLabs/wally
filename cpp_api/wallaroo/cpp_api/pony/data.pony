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

type DataP is Pointer[U8] val

class CPPData
  var _data: Pointer[U8] val

  new create(data: Pointer[U8] val) =>
    _data = data

  fun obj(): DataP val =>
    _data

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_data)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_data, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _data = recover @w_user_serializable_deserialize(bytes) end

  fun _final() =>
    @w_managed_object_delete(_data)
