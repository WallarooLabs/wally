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

use "../collection_helpers"
use "collections"
use "debug"
use "itertools"
use "json"
use "ponytest"
use "wallaroo/core/common"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestEncodeDecodeClusterStatus)
    test(_TestSourceIdsEncodeDecode)
    test(_TestStateEntityEncode)

class iso _TestSourceIdsEncodeDecode is UnitTest
  fun name(): String => "query_json/test_source_ids_encode_decode"

  fun apply(h: TestHelper) ? =>
    let source_ids: Array[String] val = ["a";"b";"c"]
    let encoded = SourceIdsQueryEncoder.response(source_ids)
    let response = SourceIdsQueryJsonDecoder.response(encoded)?
    for i in Range(0, source_ids.size()) do
      h.assert_eq[String](response.source_ids(i)?, source_ids(i)?)
    end

class iso _TestStateEntityEncode is UnitTest
  fun name(): String => "query_json/test_state_entity_encode"

  fun apply(h: TestHelper) ? =>
    let source_ids_a: Array[Key] val = ["a";"b";"c"]
    let source_ids_b: Array[Key] val = ["x";"y";"z"]
    let e = recover trn Map[String, Array[Key] val] end
    e.update("worker_a", source_ids_a)
    e.update("worker_b", source_ids_b)
    let encoded = StateEntityQueryEncoder.state_entity_keys(consume e)

    let d = JsonDoc
    d.parse(encoded)?
    let o = d.data as JsonObject
    let worker_a : JsonArray = o.data("worker_a")? as JsonArray
    let worker_b : JsonArray = o.data("worker_b")? as JsonArray

    _AssertJsonArrayEq(h, worker_a, source_ids_a)?


class iso _TestEncodeDecodeClusterStatus is UnitTest
  fun name(): String => "query_json/encode_decode_cluster_status"

  fun apply(h: TestHelper) ? =>
    var stop_the_world_in_process = false
    var is_processing = not stop_the_world_in_process
    var worker_count: U64 = 3
    var worker_names = recover val ["w1"; "w2"; "w3"] end
    let json1 = ClusterStatusQueryJsonEncoder.response(worker_count,
      worker_names, stop_the_world_in_process)
    let decoded1 = ClusterStatusQueryJsonDecoder.response(json1)?
    h.assert_eq[Bool](is_processing, decoded1.processing_messages)
    h.assert_eq[U64](worker_count, decoded1.worker_count)
    for i in Range(0, worker_count.usize()) do
      h.assert_eq[String](worker_names(i)?, decoded1.worker_names(i)?)
    end

    stop_the_world_in_process = true
    is_processing = not stop_the_world_in_process
    worker_count = 5
    worker_names = recover val ["w1"; "w2"; "w3"; "w4"; "w5"] end
    let json2 = ClusterStatusQueryJsonEncoder.response(worker_count,
      worker_names, stop_the_world_in_process)
    let decoded2 = ClusterStatusQueryJsonDecoder.response(json2)?
    h.assert_eq[Bool](is_processing, decoded2.processing_messages)
    h.assert_eq[U64](worker_count, decoded2.worker_count)
    for i in Range(0, worker_count.usize()) do
      h.assert_eq[String](worker_names(i)?, decoded2.worker_names(i)?)
    end

primitive _AssertJsonArrayEq
  fun apply(h: TestHelper, json_arr: JsonArray, arr: Array[Key] val) ? =>
    for i in Range(0, json_arr.data.size()) do
      h.assert_eq[String](json_arr.data(i)? as String, arr(i)?)
    end

primitive JsonEq
  fun parsed(s: String, t: String): Bool ? =>
    let s' = JsonDoc
    let t' = JsonDoc
    s'.parse(s) ?
    t'.parse(t) ?
    JsonEq(s'.data, t'.data)

  fun apply(v1: JsonType, v2: JsonType) : Bool =>
    match (v1,v2)
    | (None, None) => true
    | (let s: F64, let t: F64) => s == t
    | (let s: I64, let t: I64) => s == t
    | (let s: Bool, let t: Bool) => s == t
    | (let s: String, let t: String) => s == t
    | (let s: JsonArray, let t: JsonArray) =>
       (s.data.size() == t.data.size()) and
       Iter[JsonType](s.data.values())
         .zip[JsonType](t.data.values())
        .all({(xy) => JsonEq(xy._1, xy._2)})
    | (let s: JsonObject, let t: JsonObject) =>
      _equal_keys(s, t) and _all_s_vals_equal_in_t(s,t)
    else
      false
    end

  fun _equal_keys(s: JsonObject, t: JsonObject) : Bool =>
    let skeys: Set[String] =
      Iter[String](s.data.keys())
      .fold[Set[String]](Set[String], {(s, el) => s.add(el)})
    let tkeys: Set[String] =
      Iter[String](t.data.keys())
      .fold[Set[String]](Set[String], {(s, el) => s.add(el)})
    skeys == tkeys

  fun _all_s_vals_equal_in_t(s: JsonObject, t: JsonObject) : Bool =>
    var res = true
    for (s_key, s_val) in s.data.pairs() do
      try
        if not JsonEq(s_val, t.data(s_key)?) then res = false; break end
      else // key doesn't exist in t
        res = false; break
      end
    end
    res
