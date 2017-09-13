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

use "collections"

use @w_key_hash[U64](key: KeyP)
use @w_key_eq[Bool](key: KeyP, other: KeyP)

type KeyP is Pointer[U8] val

class CPPKey is (Hashable & Equatable[CPPKey])
  var _key: KeyP

  new create(key: KeyP) =>
    _key = key

  fun obj(): KeyP val =>
    _key

  fun hash(): U64 =>
    @w_key_hash(obj())

  fun eq(other: CPPKey box): Bool =>
    @w_key_eq(obj(), other.obj())

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_key)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_key, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _key = recover @w_user_serializable_deserialize(bytes) end

  fun _final() =>
    @w_managed_object_delete(_key)
