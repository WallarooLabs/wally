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
