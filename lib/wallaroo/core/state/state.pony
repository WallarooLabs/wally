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
use "serialise"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"

trait ref State

trait val StateEncoderDecoder[S: State ref]
  fun encode(state: S, auth: AmbientAuth): ByteSeq
  fun decode(in_reader: Reader, auth: AmbientAuth): S ?

primitive PonySerializeStateEncoderDecoder[S: State ref] is
  StateEncoderDecoder[S]
  fun encode(state: S, auth: AmbientAuth): ByteSeq =>
    try
      Serialised(SerialiseAuth(auth), state)?.output(OutputSerialisedAuth(
        auth))
    else
      Fail()
      recover Array[U8] end
    end

  fun decode(in_reader: Reader, auth: AmbientAuth): S ? =>
    try
      let data: Array[U8] iso = in_reader.block(in_reader.size())?
      match Serialised.input(InputSerialisedAuth(auth), consume data)(
        DeserialiseAuth(auth))?
      | let s: S => s
      else
        error
      end
    else
      error
    end

interface val StateInitializer[In: Any val, Out: Any val, S: State ref] is
  Computation[In, Out]
  fun val state_wrapper(key: Key): StateWrapper[In, Out, S]
  fun name(): String
  fun val decode(in_reader: Reader, auth: AmbientAuth):
    StateWrapper[In, Out, S] ?

trait ref StateWrapper[In: Any val, Out: Any val, S: State ref]
  // Return (output, output_watermark_ts)
  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)
  fun ref on_timeout(wall_time: U64):
    ((Out | Array[Out] val | None), U64)
  fun ref encode(auth: AmbientAuth): ByteSeq

class EmptyState is State
