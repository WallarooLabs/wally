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

interface val KafkaSinkEncoder[In: Any val]
  // Returns a tuple (encoded_value, encoded_key) where you can pass None
  // for the encoded_key if there is none
  fun apply(input: In, wb: Writer):
    ((ByteSeq | Array[ByteSeq] val), (None | ByteSeq | Array[ByteSeq] val))

trait val KafkaEncoderWrapper
  fun encode[D: Any val](d: D, wb: Writer):
    ((ByteSeq | Array[ByteSeq] val), (None | ByteSeq | Array[ByteSeq] val)) ?

class val TypedKafkaEncoderWrapper[In: Any val] is KafkaEncoderWrapper
  let _encoder: KafkaSinkEncoder[In] val

  new val create(e: KafkaSinkEncoder[In] val) =>
    _encoder = e

  fun encode[D: Any val](data: D, wb: Writer):
    ((ByteSeq | Array[ByteSeq] val), (None | ByteSeq | Array[ByteSeq] val)) ?
  =>
    match data
    | let i: In =>
      _encoder(i, wb)
    else
      error
    end
