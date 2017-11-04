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

primitive MapEquality[K: (Hashable #read & Equatable[K] #read),
  V: Equatable[V] #read]
  fun apply(m1: box->Map[K, V], m2: box->Map[K, V]): Bool =>
    if m1.size() != m2.size() then return false end
    try
      for (k, v) in m1.pairs() do
        if m2(k)? != v then return false end
      end
      true
    else
      false
    end

primitive MapEquality2[K: (Hashable #read & Equatable[K] #read),
  V1: Equatable[V1] #read, V2: Equatable[V2] #read]
  fun apply(m1: box->Map[K, (V1 | V2)], m2: box->Map[K, (V1 | V2)]): Bool =>
    if m1.size() != m2.size() then return false end
    try
      for (k, v) in m1.pairs() do
        if not OrEq2[V1, V2](m2(k)?, v) then return false end
      end
      true
    else
      false
    end

primitive MapEquality3[K: (Hashable #read & Equatable[K] #read),
  V1: Equatable[V1] #read, V2: Equatable[V2] #read, V3: Equatable[V3] #read]
  fun apply(m1: box->Map[K, (V1 | V2 | V3)],
    m2: box->Map[K, (V1 | V2 | V3)]): Bool
  =>
    if m1.size() != m2.size() then return false end
    try
      for (k, v) in m1.pairs() do
        if not OrEq3[V1, V2, V3](m2(k)?, v) then return false end
      end
      true
    else
      false
    end

primitive MapTagEquality[K: (Hashable #read & Equatable[K] #read), V: Any tag]
  fun apply(m1: box->Map[K, V], m2: box->Map[K, V]): Bool =>
    if m1.size() != m2.size() then return false end
    try
      for (k, v) in m1.pairs() do
        if m2(k)? isnt v then return false end
      end
      true
    else
      false
    end

primitive ArrayEquality[V: Equatable[V] #read]
  fun apply(a1: box->Array[V], a2: box->Array[V]): Bool =>
    if a1.size() != a2.size() then return false end
    try
      for idx in Range(0, a1.size()) do
        if a1(idx)? != a2(idx)? then return false end
      end
      true
    else
      false
    end

primitive OrEq2[A: Equatable[A] #read, B: Equatable[B] #read]
  fun apply(v1: (box->A | box->B), v2: (box->A | box-> B)): Bool =>
    match v1
    | let v1a: box->A =>
      match v2
      | let v2a: box->A =>
        v1a == v2a
      else
        false
      end
    | let v1b: box->B =>
      match v2
      | let v2b: box->B =>
        v1b == v2b
      else
        false
      end
    end

primitive OrEq3[A: Equatable[A] #read, B: Equatable[B] #read,
  C: Equatable[C] #read]
  fun apply(v1: (box->A | box->B | box->C),
    v2: (box->A | box->B | box->C)): Bool
  =>
    match v1
    | let v1a: box->A =>
      match v2
      | let v2a: box->A =>
        v1a == v2a
      else
        false
      end
    | let v1b: box->B =>
      match v2
      | let v2b: box->B =>
        v1b == v2b
      else
        false
      end
    | let v1c: box->C =>
      match v2
      | let v2c: box->C =>
        v1c == v2c
      else
        false
      end
    end
