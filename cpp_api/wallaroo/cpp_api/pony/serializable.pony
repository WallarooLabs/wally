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

use @w_serializable_serialize_get_size[USize](data: ManagedObjectP)
use @w_serializable_serialize[None](data: ManagedObjectP,
  bytes: Pointer[U8] tag)
use @w_user_serializable_deserialize[ManagedObjectP](bytes: Pointer[U8] tag)
