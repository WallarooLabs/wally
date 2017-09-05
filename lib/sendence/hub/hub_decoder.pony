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
use "collections"
use "wallaroo/metrics"

primitive HubProtocolDecoder
  fun apply(data: Array[U8 val] val): HubProtocolMsg ? =>
    match _decode(data)
    | (_Join(), let d: Array[U8 val] val) =>
      HubJoinMsg
    | (_Connect(), let d: Array[U8 val] val) =>
      HubConnectMsg
    | (_Payload(), let d: Array[U8 val] val) =>
      HubPayloadMsg(d)
    else
      error
    end

  fun _decode(data: Array[U8 val] val): (U8, Array[U8 val] val) ? =>
    let rb = Reader
    rb.append(data)
    let msg_id = rb.u8()
    let data_len = data.size() - 1
    let data' = rb.block(data_len)
    (msg_id, consume data')

primitive _Join    fun apply(): U8 => 1
primitive _Connect fun apply(): U8 => 2
primitive _Payload fun apply(): U8 => 3


trait val HubProtocolMsg

primitive HubJoinMsg is HubProtocolMsg
primitive HubConnectMsg is HubProtocolMsg
primitive HubOtherMsg is HubProtocolMsg

primitive HubPayloadMsg is HubProtocolMsg
  fun apply(data: Array[U8] val): HubProtocolMsg =>
    try
      let rb = Reader
      rb.append(data)
      let event_size = rb.u32_be().usize()
      let event = String.from_array(rb.block(event_size))
      let topic_size = rb.u32_be().usize()
      let topic = String.from_array(rb.block(topic_size))
      let data_size = rb.u32_be().usize()
      let data' = rb.block(data_size)
      match event
      | "metrics" =>
        HubMetricsMsg(consume data')
      else
        @printf[I32]("event: %s\n".cstring(), event.cstring())
        HubOtherMsg
      end
    else
      HubOtherMsg
    end

class val HubMetricsMsg is HubProtocolMsg
  var name: String = ""
  var category: String = ""
  var pipeline_name: String = ""
  var worker_name: String = ""
  var id: U16 = 0
  var period_ends_at: U64 = 0
  var period: U64 = 0
  var histogram_min: U64 = 0
  var histogram_max: U64 = 0
  var histogram: Array[U64] = Array[U64]

  new val create(data: Array[U8] val) ? =>
    try
      let rb = Reader
      rb.append(data)
      let header_size = rb.u32_be().usize()
      let name_size = rb.u32_be().usize()
      name = String.from_array(rb.block(name_size))
      let category_size = rb.u32_be().usize()
      category = String.from_array(rb.block(category_size))
      let worker_name_size = rb.u32_be().usize()
      worker_name = String.from_array(rb.block(worker_name_size))
      let pipeline_name_size = rb.u32_be().usize()
      pipeline_name = String.from_array(rb.block(pipeline_name_size))
      id = rb.u16_be()
      match category
        | "start-to-end" =>
          name = pipeline_name + "@" + worker_name
        | "node-ingress-egress" =>
          name = pipeline_name + "*" + worker_name
        | "computation" =>
          name = pipeline_name + "@" + worker_name
            + ": " + id.string() + " - " + name
        end
      for i in Range[U64](0, 65) do
        let bin = rb.u64_be()
        histogram.push(bin)
      end
      histogram_min = rb.u64_be()
      histogram_max = rb.u64_be()
      period = rb.u64_be()
      period_ends_at = rb.u64_be()
    else
      error
    end
