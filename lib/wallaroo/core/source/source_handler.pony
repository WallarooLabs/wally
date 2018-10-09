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

interface SourceHandler[In: Any val]
  fun decode(data: Array[U8] val): In ?

interface FramedSourceHandler[In: Any val]
  fun header_length(): USize
  fun payload_length(data: Array[U8] iso): USize ?
  fun decode(data: Array[U8] val): In ?

interface val Decoder[In: Any val]
  fun decode(data: Array[U8] val): In ?

