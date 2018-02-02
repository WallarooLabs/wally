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
use "../mort"


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


primitive PartitionQueryEncoder
  fun _quoted(s: String): String =>
    "\"" + s + "\""

  fun _encode(entries: Array[String] val, json_delimiters: _JsonDelimiters):
    String
  =>
    recover
      var s: Array[U8] iso = recover Array[U8] end
      s.>append(json_delimiters()._1)
       .>append(",".join(entries.values()))
       .>append(json_delimiters()._2)
      String.from_array(consume s)
    end

  fun partition_entities(se: _StepIds): String =>
    _encode(se, _JsonArray)

  fun partition_entities_by_worker(se: _StepIdsByWorker): String =>
    let entries = recover iso Array[String] end
    for (k, v) in se.pairs() do
      entries.push(_quoted(k) + ":" + partition_entities(v))
    end
    _encode(consume entries, _JsonMap)

  fun partitions(qm: _PartitionQueryMap): String =>
    let entries = recover iso Array[String] end
    for (k, v) in qm.pairs() do
      entries.push(_quoted(k) + ":" + partition_entities_by_worker(v))
    end
    _encode(consume entries, _JsonMap)

  fun state_and_stateless(m: Map[String, _PartitionQueryMap]): String =>
    let entries = recover iso Array[String] end
    try
      entries.push("state_partitions:" + partitions(m("state_partitions")?))
      entries.push("stateless_partitions:" +
        partitions(m("stateless_partitions")?))
    else
      Fail()
    end
    _encode(consume entries, _JsonMap)

primitive PartitionQueryDecoder
  fun partition_entities(se: String): _StepIds =>
    let entities = recover iso Array[String] end
    var word = recover iso Array[U8] end
    for i in Range(1, se.size()) do
      let next_char = try se(i)? else Fail(); ' ' end
      if next_char == ',' then
        entities.push(String.from_array(
          word = recover iso Array[U8] end))
      elseif next_char != ']' then
        word.push(next_char)
      end
    end
    entities.push(String.from_array(word = recover iso Array[U8] end))
    consume entities

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
