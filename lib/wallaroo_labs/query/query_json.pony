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
use "../messages"
use "../mort"
use "../../wallaroo/core/common"

type _JsonDelimiters is (_JsonString | _JsonArray | _JsonMap)

primitive _JsonString
  fun apply(): (String, String) => ("\"", "\"")
primitive _JsonArray
  fun apply(): (String, String) => ("[", "]")
primitive _JsonMap
  fun apply(): (String, String) => ("{", "}")


type _StepIds is Array[String] val

type _StepIdsByWorker is Map[String, _StepIds] val

type _PartitionQueryMap is Map[String, _StepIdsByWorker] val


primitive _Quoted
  fun apply(s: String): String =>
    "\"" + s + "\""

primitive _JsonEncoder
  fun apply(entries: Array[String] val, json_delimiters: _JsonDelimiters,
    quote_entries: Bool = false):
    String
  =>
    recover
      var s: Array[U8] iso = recover Array[U8] end
      s.>append(json_delimiters()._1)
       .>append(",".join(
           if quote_entries then
             Iter[String](entries.values()).map[String](
               {(s)=> _Quoted(s)})
           else
             entries.values()
           end
         ))
       .>append(json_delimiters()._2)
      String.from_array(consume s)
    end

primitive PartitionQueryEncoder
  fun partition_entities(se: _StepIds): String =>
    _JsonEncoder(se, _JsonArray)

  fun partition_entities_by_worker(se: _StepIdsByWorker): String =>
    let entries = recover iso Array[String] end
    for (k, v) in se.pairs() do
      entries.push(_Quoted(k) + ":" + partition_entities(v))
    end
    _JsonEncoder(consume entries, _JsonMap)

  fun partitions(qm: _PartitionQueryMap): String =>
    let entries = recover iso Array[String] end
    for (k, v) in qm.pairs() do
      entries.push(_Quoted(k) + ":" + partition_entities_by_worker(v))
    end
    _JsonEncoder(consume entries, _JsonMap)

  fun partition_counts_by_worker(se: _StepIdsByWorker): String =>
    let entries = recover iso Array[String] end
    for (k, v) in se.pairs() do
      entries.push(_Quoted(k) + ":" + v.size().string())
    end
    _JsonEncoder(consume entries, _JsonMap)

  fun partition_counts(qm: _PartitionQueryMap): String =>
    let entries = recover iso Array[String] end
    for (k, v) in qm.pairs() do
      entries.push(_Quoted(k) + ":" + partition_counts_by_worker(v))
    end
    _JsonEncoder(consume entries, _JsonMap)

  fun state_and_stateless(m: Map[String, _PartitionQueryMap]): String =>
    let entries = recover iso Array[String] end
    try
      entries.push(_Quoted("state_partitions") + ":" +
        partitions(m("state_partitions")?))
      entries.push(_Quoted("stateless_partitions") + ":" +
        partitions(m("stateless_partitions")?))
    else
      Fail()
    end
    _JsonEncoder(consume entries, _JsonMap)

  fun state_and_stateless_by_count(m: Map[String, _PartitionQueryMap]):
    String
  =>
    let entries = recover iso Array[String] end
    try
      entries.push(_Quoted("state_partitions") + ":" +
        partition_counts(m("state_partitions")?))
      entries.push(_Quoted("stateless_partitions") + ":" +
        partition_counts(m("stateless_partitions")?))
    else
      Fail()
    end
    _JsonEncoder(consume entries, _JsonMap)

primitive ShrinkQueryJsonEncoder
  fun request(query: Bool, node_names: Array[String] val, node_count: U64):
    String
  =>
    let entries = recover iso Array[String] end
    entries.push(_Quoted("query") + ":" + query.string())
    entries.push(_Quoted("node_names") + ":" + _JsonEncoder(node_names,
      _JsonArray))
    entries.push(_Quoted("node_count") + ":" + node_count.string())
    _JsonEncoder(consume entries, _JsonMap)

  fun response(node_names: Array[String] val, node_count: U64): String =>
    let entries = recover iso Array[String] end
    entries.push(_Quoted("node_names") + ":" + _JsonEncoder(node_names,
      _JsonArray))
    entries.push(_Quoted("node_count") + ":" + node_count.string())
    _JsonEncoder(consume entries, _JsonMap)

primitive ClusterStatusQueryJsonEncoder
  fun response(worker_count: U64, worker_names: Array[String] val,
    stop_the_world_in_process: Bool): String
  =>
    let entries = recover iso Array[String] end
    entries.push(_Quoted("processing_messages") + ":" +
      (not stop_the_world_in_process).string())
    entries.push(_Quoted("worker_names") + ":" + _JsonEncoder(worker_names,
      _JsonArray, true))
    entries.push(_Quoted("worker_count") + ":" + worker_count.string())
    _JsonEncoder(consume entries, _JsonMap)

primitive SourceIdsQueryEncoder
  fun response(source_ids: Array[String] val): String =>
    _JsonEncoder(source_ids, _JsonArray)

primitive JsonDecoder
  fun string_array(s: String): Array[String] val =>
    let items = recover iso Array[String] end
    var str = recover iso Array[U8] end
    if s.size() > 1 then
      for i in Range(1, s.size()) do
        let next_char = try s(i)? else Fail(); ' ' end
        if next_char == ',' then
          items.push(String.from_array(
            str = recover iso Array[U8] end))
        elseif (next_char != ']') and (next_char != '"') then
          str.push(next_char)
        end
      end
      items.push(String.from_array(str = recover iso Array[U8] end))
    end
    consume items

primitive PartitionQueryDecoder
  fun partition_entities(se: String): _StepIds =>
    JsonDecoder.string_array(se)

  fun partition_entities_by_worker(se: String): _StepIdsByWorker =>
    let entities = recover iso Map[String, _StepIds] end
    var is_key = true
    var after_list = false
    var next_key = recover iso Array[U8] end
    var next_list = recover iso Array[U8] end
    for i in Range(1, se.size()) do
      let next_char = try se(i)? else Fail(); ' ' end
      if after_list then
        if next_char == ',' then
          after_list = false
          is_key = true
        end
      elseif is_key then
        if next_char == ':' then
          is_key = false
        elseif next_char != '"' then
          next_key.push(next_char)
        end
      else
        if next_char == ']' then
          let key = String.from_array(next_key = recover iso Array[U8] end)
          let list = String.from_array(next_list = recover iso Array[U8] end)
          entities(key) = partition_entities(list)
          after_list = true
        else
          next_list.push(next_char)
        end
      end
    end
    consume entities

  fun partitions(qm: String): _PartitionQueryMap =>
    let entities = recover iso Map[String, _StepIdsByWorker] end
    var is_key = true
    var after_map = false
    var next_key = recover iso Array[U8] end
    var next_map = recover iso Array[U8] end
    for i in Range(1, qm.size()) do
      let next_char = try qm(i)? else Fail(); ' ' end
      if after_map then
        if next_char == ',' then
          after_map = false
          is_key = true
        end
      elseif is_key then
        if next_char == ':' then
          is_key = false
        elseif next_char != '"' then
          next_key.push(next_char)
        end
      else
        if next_char == '}' then
          let key = String.from_array(next_key = recover iso Array[U8] end)
          let map = String.from_array(next_map = recover iso Array[U8] end)
          entities(key) = partition_entities_by_worker(map)
          after_map = true
        else
          next_map.push(next_char)
        end
      end
    end
    consume entities

  fun state_and_stateless(json: String): Map[String, _PartitionQueryMap] val =>
    let p_map = recover iso Map[String, _PartitionQueryMap] end
    var is_key = true
    var after_map = false
    var next_key = recover iso Array[U8] end
    var next_map = recover iso Array[U8] end
    for i in Range(1, json.size()) do
      let next_char = try json(i)? else Fail(); ' ' end
      if after_map then
        if next_char == ',' then
          after_map = false
          is_key = true
        end
      elseif is_key then
        if next_char == ':' then
          is_key = false
        elseif next_char != '"' then
          next_key.push(next_char)
        end
      else
        if next_char == '}' then
          let key = String.from_array(next_key = recover iso Array[U8] end)
          let map = String.from_array(next_map = recover iso Array[U8] end)
          p_map(key) = partitions(map)
          after_map = true
        else
          next_map.push(next_char)
        end
      end
    end
    consume p_map

primitive ShrinkQueryJsonDecoder
  fun request(json: String): ExternalShrinkRequestMsg ? =>
    let p_map = Map[String, String]
    var is_key = true
    var this_key = ""
    var next_key = recover iso Array[U8] end
    var next_str = recover iso Array[U8] end
    for i in Range(1, json.size()) do
      let next_char = json(i)?
      if is_key then
        if next_char == ':' then
          is_key = false
          this_key = String.from_array(next_key = recover iso Array[U8] end)
        elseif (next_char != '"') and (next_char != ',') then
          next_key.push(next_char)
        end
      else
        let delimiter: U8 =
          match this_key
          | "query" => ','
          | "node_names" => ']'
          | "node_count" => '}'
          else error
          end
        if next_char == delimiter then
          let str = String.from_array(next_str = recover iso Array[U8] end)
          p_map(this_key) = str
          is_key = true
        else
          next_str.push(next_char)
        end
      end
    end

    let query_string = p_map("query")?
    let query = if query_string == "true" then true else false end

    let names_string = p_map("node_names")?
    let node_names = JsonDecoder.string_array(names_string)

    let node_count: U64 = p_map("node_count")?.u64()?

    ExternalShrinkRequestMsg(query, node_names, node_count)

  fun response(json: String): ExternalShrinkQueryResponseMsg ? =>
    let p_map = Map[String, String]
    var is_key = true
    var this_key = ""
    var next_key = recover iso Array[U8] end
    var next_str = recover iso Array[U8] end
    for i in Range(1, json.size()) do
      let next_char = json(i)?
      if is_key then
        if next_char == ':' then
          is_key = false
          this_key = String.from_array(next_key = recover iso Array[U8] end)
        elseif (next_char != '"') and (next_char != ',') then
          next_key.push(next_char)
        end
      else
        let delimiter: U8 =
          match this_key
          | "node_names" => ']'
          | "node_count" => '}'
          else error
          end
        if next_char == delimiter then
          let str = String.from_array(next_str = recover iso Array[U8] end)
          p_map(this_key) = str
          is_key = true
        else
          next_str.push(next_char)
        end
      end
    end

    let names_string = p_map("node_names")?
    let node_names = JsonDecoder.string_array(names_string)

    let node_count: U64 = p_map("node_count")?.u64()?

    ExternalShrinkQueryResponseMsg(node_names, node_count)

primitive ClusterStatusQueryJsonDecoder
  fun response(json: String): ExternalClusterStatusQueryResponseMsg ? =>
    let p_map = Map[String, String]
    var is_key = true
    var this_key = ""
    var next_key = recover iso Array[U8] end
    var next_str = recover iso Array[U8] end
    for i in Range(1, json.size()) do
      let next_char = json(i)?
      if is_key then
        if next_char == ':' then
          is_key = false
          this_key = String.from_array(next_key = recover iso Array[U8] end)
        elseif (next_char != '"') and (next_char != ',') then
          next_key.push(next_char)
        end
      else
        let delimiter: U8 =
          match this_key
          | "processing_messages" => ','
          | "worker_names" => ']'
          | "worker_count" => '}'
          else error
          end
        if next_char == delimiter then
          let str = String.from_array(next_str = recover iso Array[U8] end)
          p_map(this_key) = str
          is_key = true
        else
          next_str.push(next_char)
        end
      end
    end

    let processing_string = p_map("processing_messages")?
    let is_processing = if processing_string == "true" then true else false end

    let workers_string = p_map("worker_names")?
    let worker_names = JsonDecoder.string_array(workers_string)

    let worker_count: U64 = p_map("worker_count")?.u64()?

    ExternalClusterStatusQueryResponseMsg(worker_count, worker_names,
      is_processing, json)

primitive SourceIdsQueryJsonDecoder
  fun response(json: String): ExternalSourceIdsQueryResponseMsg =>
    let source_ids = JsonDecoder.string_array(json)
    ExternalSourceIdsQueryResponseMsg(source_ids)
