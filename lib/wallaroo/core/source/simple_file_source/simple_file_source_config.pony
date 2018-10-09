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

use "options"
use "wallaroo"
use "wallaroo/core/source"

class val SimpleFileSourceConfig[In: Any val]
  let _filename: String
  let _decoder: Decoder[In]
  let _is_repeating: Bool

  new val create(filename: String, decoder: Decoder[In], is_repeating: Bool)
  =>
    _filename = filename
    _decoder = decoder
    _is_repeating = is_repeating

  fun source_listener_builder_builder():
    SimpleFileSourceListenerBuilderBuilder[In]
  =>
    SimpleFileSourceListenerBuilderBuilder[In](_filename, _decoder,
      _is_repeating)
