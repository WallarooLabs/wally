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
use "wallaroo/core/common"
use "wallaroo_labs/mort"

primitive SetHelpers[V]
  fun forall(s: SetIs[V] box, pred: {(box->V!): Bool}): Bool =>
    for v in s.values() do
      if not pred(v) then return false end
    end
    true

  fun some(s: SetIs[V] box, pred: {(box->V!): Bool}): Bool =>
    for v in s.values() do
      if pred(v) then return true end
    end
    false

  fun contains[A: Equatable[A] #read](arr: SetIs[A] box, v: A): Bool =>
    for a in arr.values() do
      if a == v then return true end
    end
    false

primitive ArrayHelpers[V]
  fun forall(arr: Array[V] box, pred: {(box->V!): Bool}): Bool =>
    for v in arr.values() do
      if not pred(v) then return false end
    end
    true

  fun some(arr: Array[V] box, pred: {(box->V!): Bool}): Bool =>
    for v in arr.values() do
      if pred(v) then return true end
    end
    false

  fun sorted[A: Comparable[A] val](arr: Array[A] val): Array[A] =>
    let unsorted = Array[A]
    for a in arr.values() do
      unsorted.push(a)
    end
    Sort[Array[A], A](unsorted)

  fun contains[A: Equatable[A] #read](arr: Array[A] box, v: A): Bool =>
    for a in arr.values() do
      if a == v then return true end
    end
    false

  fun eq[A: Equatable[A] #read](arr1: Array[A] box, arr2: Array[A] box): Bool
  =>
    if arr1.size() == arr2.size() then
      for i in Range(0, arr1.size()) do
        try
          if arr1(i)? != arr2(i)? then return false end
        else
          return false
        end
      end
    else
      return false
    end
    true

primitive HashableKey
  fun hash(k: box->Key!): USize =>
    @ponyint_hash_block[USize](k.cpointer(0), k.size())

  fun eq(x: box->Key!, y: box->Key!): Bool =>
    if x.size() != y.size() then
      false
    else
      @memcmp[I32](x.cpointer(0), y.cpointer(0), x.size()) == 0
    end

  fun string(k: Key): String =>
    k
