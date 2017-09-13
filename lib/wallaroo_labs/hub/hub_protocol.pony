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
use "wallaroo_labs/bytes"
use "wallaroo/core/metrics"

primitive HubProtocol
  fun connect(wb: Writer = Writer): Array[ByteSeq] val =>
    wb.u32_be(1)
    wb.u8(HubMsgTypes.connect())
    wb.done()

  fun join_metrics(topic: String, worker_name: String,
    wb: Writer = Writer): Array[ByteSeq] val
  =>
    let size = (1 + 4 + topic.size() + 4 + worker_name.size()).u32()
    wb.u32_be(size)
    wb.u8(HubMsgTypes.join())
    wb.u32_be(topic.size().u32())
    wb.write(topic.array())
    wb.u32_be(worker_name.size().u32())
    wb.write(worker_name.array())
    wb.done()

  fun join(topic: String, wb: Writer = Writer): Array[ByteSeq] val =>
    let size = (1 + 4 + topic.size()).u32()
    wb.u32_be(size)
    wb.u8(HubMsgTypes.join())
    wb.u32_be(topic.size().u32())
    wb.write(topic.array())
    wb.done()

  fun payload(event: String, topic: String, data: Array[ByteSeq] val,
    wb: Writer)
  =>
    let event_size = event.size().u32()
    let topic_size = topic.size().u32()
    var data_size: U32 = 0
    for seq in data.values() do
      data_size = data_size + seq.size().u32()
    end
    let size_of_sizes: U32  = 12
    let size = 1 + event_size + topic_size + data_size + size_of_sizes
    wb.u32_be(size)
    wb.u8(HubMsgTypes.payload())
    wb.u32_be(event_size)
    wb.write(event)
    wb.u32_be(topic_size)
    wb.write(topic)
    wb.u32_be(data_size)
    wb.writev(data)

  fun payload_into_array(event: String, topic: String, data: Array[U8] iso):
    Array[ByteSeq] val
  =>
    let encoded = recover trn Array[ByteSeq](2) end

    // Determine sizes
    let event_size = event.size().u32()
    let topic_size = topic.size().u32()
    let data_size = data.size().u32()
    let size_of_sizes: U32  = 12
    let size = 1 + event_size + topic_size + data_size + size_of_sizes

    // Encode into array
    var header_arr: Array[U8] iso = recover Array[U8](size.usize()) end
    header_arr = Bytes.from_u32(size, consume header_arr)
    header_arr.push(HubMsgTypes.payload())
    header_arr = Bytes.from_u32(event_size, consume header_arr)
    for byte in event.array().values() do
      header_arr.push(byte)
    end
    header_arr = Bytes.from_u32(topic_size, consume header_arr)
    for byte in topic.array().values() do
      header_arr.push(byte)
    end
    header_arr = Bytes.from_u32(data_size, consume header_arr)

    encoded.push(consume header_arr)
    encoded.push(consume data)
    consume encoded

  fun metrics(name: String, category: String, pipeline_name: String,
    worker_name: String, id: U16, histogram: Histogram val,
    period: U64, period_ends_at: U64, wb: Writer)
  =>
    let name_size = name.size().u32()
    let category_size = category.size().u32()
    let worker_name_size = worker_name.size().u32()
    let pipeline_name_size = pipeline_name.size().u32()
    let size = 4 + 4 + 4 + 4 + 2 + name_size + category_size +
      worker_name_size + pipeline_name_size + (64 * 11)
    wb.u32_be(size)
    wb.u32_be(name_size)
    wb.write(name)
    wb.u32_be(category_size)
    wb.write(category)
    wb.u32_be(worker_name_size)
    wb.write(worker_name)
    wb.u32_be(pipeline_name_size)
    wb.write(pipeline_name)
    wb.u16_be(id)
    for metric in histogram.counts().values() do
      wb.u64_be(metric)
    end
    wb.u64_be(histogram.min())
    wb.u64_be(histogram.max())
    wb.u64_be(period)
    wb.u64_be(period_ends_at)

primitive HubMsgTypes
  fun connect(): U8 => 1
  fun join(): U8 => 2
  fun payload(): U8 => 3
