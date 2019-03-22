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

"""
The fundamental types of the multi partition detector are:
1. Key: the partition key, a String.
2. Value: a single U64 value, such as the one sent from the external source.
3: Window: a window (ring buffer) of recently seen Values.
4. Payload: either a Window or a Value.
5. Message: A tuple of a Key and a Payload.

Then the following constraints are required:
- The Decoder returns a Message val
- Partition functions operate on Message.key(): String
- All computations return Message val
- All computation take Message val as their input (optionally in addition to
  State if they are stateful)
- Encoder takes Message as its input.
"""

use "time"
use "regex"
use "../ring"
use "../window_codecs"
use "wallaroo_labs/mort"

type Key is String
type Value is U64
primitive WindowSize
  fun apply(): USize => 4
type Window is Ring[U64]
type Payload is (Window | Value)

trait Partitionable
  fun key(): String

trait Computable
  fun value(): U64

primitive Timestamp
  fun apply(): String =>
    Time.nanos().string()

class val Message is (Partitionable & Computable)
  """
  The type that all computations in a multi-partition-detector application
  should return as their result.
  """
  let _key: String
  let _trace: String
  let _payload: Payload val
  let _ts: String

  new val create(k: Key, trace': String, p: Payload val,
    ts': (String | None) = None)
  =>
    _key = k
    _trace = trace'
    _payload = p
    _ts = match ts'
    | let t: String =>
      t
    else
      Timestamp()
    end

  fun ts(): String =>
    _ts

  fun key(): String =>
    _key

  fun trace(): String =>
    _trace

  fun value(): U64 =>
    match _payload
    | let p: Window val =>
      try
        p(0)?
      else
        @printf[I32]("Encountered illegal state: empty Window in Message!\n"
          .cstring())
        Fail()
        0
      end
    | let v: U64 => v
    end

  fun string(): String =>
    let data: String = match _payload
    | let p: Window val =>
      try
        p.string(where fill = "0")?
      else
        "Error: failed to convert sequence window into a string."
        Fail()
        ""
      end
    | let v: Value val => v.string()
    end
    ("{\"key\": \"" + _key + "\", \"value\": " + data +
      ", \"trace\": \"" + _trace + "\", \"ts\": \"" + _ts + "\"}")

  fun window(): Window val ? =>
    match _payload
    | let p: Window val => p
    else
      error
    end
