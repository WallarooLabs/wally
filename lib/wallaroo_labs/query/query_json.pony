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
use "itertools"
use "json"
use "../messages"
use "../../wallaroo/core/common"

type _StepIds is Array[String] val
type _StepIdsByWorker is Map[String, _StepIds] val
type _PartitionQueryMap is Map[String, _StepIdsByWorker] val

primitive PartitionQueryStateAndStatelessIdsEncoder
  fun apply(m: Map[String, _PartitionQueryMap] val): String =>
    _PartitionQueryEncoder(m
      where step_ids_to_json = _EncodeStringArray~apply())

primitive PartitionQueryStateAndStatelessCountsEncoder
  fun apply(m: Map[String, _PartitionQueryMap] val): String =>
    _PartitionQueryEncoder(m
      where step_ids_to_json = _EncodeArrayLength~apply())

primitive StateEntityQueryEncoder
  fun state_entity_keys(
    digest: Map[String, Array[String] val] val):
    String
  =>
    let o = JsonObject
    for (k,vs) in digest.pairs() do o.data(k) = _EncodeStringArray(vs) end
    o.string()

primitive StateEntityCountQueryEncoder
  fun state_entity_count(
    digest: Map[String, Array[String] val] val):
    String
  =>
    let o = JsonObject
    for (k,v) in digest.pairs() do o.data(k) = _EncodeArrayLength(v) end
    o.string()


primitive StatelessPartitionQueryEncoder
  fun stateless_partition_keys(
    stateless_parts: Map[String, Map[String, Array[String] val] val] val):
    String
  =>
    let o = JsonObject
    for (key,worker_parts) in stateless_parts.pairs() do
      let o' = JsonObject
      for (worker, parts) in worker_parts.pairs() do
        o'.data(worker) = _EncodeStringArray(parts)
      end
      o.data(key) = o'
    end
    o.string()


primitive StatelessPartitionCountQueryEncoder
  fun stateless_partition_count(
    stateless_parts: Map[String, Map[String, Array[String] val] val] val):
    String
  =>
    let o = JsonObject
    for (key,worker_parts) in stateless_parts.pairs() do
      let o' = JsonObject
      for (worker, parts) in worker_parts.pairs() do
        o'.data(worker) = _EncodeArrayLength(parts)
      end
      o.data(key) = o'
    end
    o.string()


primitive ShrinkQueryJsonEncoder
  fun request(query: Bool, node_names: Array[String] val, node_count: U64):
    String
  =>
    let o = JsonObject
    o.data("query") = query
    o.data("node_names") = _EncodeStringArray(node_names)
    o.data("node_count") = I64.from[U64](node_count)
    o.string()

  fun response(node_names: Array[String] val, node_count: U64): String =>
    let o = JsonObject
    o.data("node_names") = _EncodeStringArray(node_names)
    o.data("node_count") = I64.from[U64](node_count)
    o.string()


primitive ClusterStatusQueryJsonEncoder
  fun response(worker_count: U64, worker_names: Array[String] val,
    stop_the_world_in_process: Bool): String
  =>
    let o = JsonObject
    o.data("worker_count") = I64.from[U64](worker_count)
    o.data("worker_names") = _EncodeStringArray(worker_names)
    o.data("processing_messages") = not stop_the_world_in_process
    o.string()


primitive SourceIdsQueryEncoder
  fun response(source_ids: Array[String] val): String =>
    let o = JsonObject
    o.data("source_ids") = _EncodeStringArray(source_ids)
    o.string()


primitive _PartitionQueryEncoder
  fun apply(
    m: Map[String, _PartitionQueryMap] val,
    step_ids_to_json: {(_StepIds): JsonType}) :
    String
  =>
    let top = JsonObject
    for (category, pm) in m.pairs() do
      let cat = JsonObject
      for (app, worker_map) in pm.pairs() do
        let app_workers = JsonObject
        for (worker, parts) in worker_map.pairs() do
          app_workers.data(worker) = step_ids_to_json(parts)
        end
        cat.data(app) = app_workers
      end
      top.data(category) = cat
    end
    top.string()


primitive ShrinkQueryJsonDecoder
  fun request(json: String): ExternalShrinkRequestMsg ? =>
    let doc = JsonDoc
    doc.parse(json)?
    let obj: JsonObject = doc.data as JsonObject
    let query = obj.data("query")? as Bool
    let arr: JsonArray = obj.data("node_names")? as JsonArray
    let node_count = U64.from[I64](obj.data("node_count")? as I64)
    let node_names = _DecodeStringArray(arr)?
    ExternalShrinkRequestMsg(query, node_names, node_count)

  fun response(json: String): ExternalShrinkQueryResponseMsg ? =>
    let doc = JsonDoc
    doc.parse(json)?
    let obj: JsonObject = doc.data as JsonObject
    let arr: JsonArray = obj.data("node_names")? as JsonArray
    let node_count = U64.from[I64](obj.data("node_count")? as I64)
    let node_names = _DecodeStringArray(arr)?
    ExternalShrinkQueryResponseMsg(node_names, node_count)


primitive ClusterStatusQueryJsonDecoder
  fun response(json: String): ExternalClusterStatusQueryResponseMsg ? =>
    let doc = JsonDoc
    doc.parse(json)?
    let obj: JsonObject = doc.data as JsonObject
    let arr: JsonArray = obj.data("worker_names")? as JsonArray
    let wn = _DecodeStringArray(arr)?
    let wc = U64.from[I64](obj.data("worker_count")? as I64)
    let p = obj.data("processing_messages")? as Bool
    ExternalClusterStatusQueryResponseMsg(wc, wn, p, json)


primitive SourceIdsQueryJsonDecoder
  fun response(json: String): ExternalSourceIdsQueryResponseMsg ? =>
    let doc = JsonDoc
    doc.parse(json)?
    let obj: JsonObject = doc.data as JsonObject
    let arr: JsonArray = obj.data("source_ids")? as JsonArray
    let sis = _DecodeStringArray(arr)?
    ExternalSourceIdsQueryResponseMsg(consume sis, json)

primitive _EncodeArrayLength
  fun apply(a: Array[String val] val) : I64 =>
    I64.from[USize](a.size())

primitive _EncodeStringArray
  fun apply(a: Array[String val] val) : JsonArray =>
    let arr = JsonArray
    for v in a.values() do arr.data.push(v) end
    arr

primitive _DecodeStringArray
  fun apply(j: JsonArray) : Array[String] val ? =>
    let result: Array[String] trn = recover trn Array[String] end
    for v in j.data.values() do result.push(v as String) end
    consume result
