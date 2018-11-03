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

use "wallaroo/core/topology"

primitive Double is Computation[U64, U64]
  fun apply(input: U64): U64 =>
    input * 2

  fun name(): String => "Double"

primitive Triple is Computation[U64, U64]
  fun apply(input: U64): U64 =>
    input * 3

  fun name(): String => "Triple"

primitive Divide is Computation[U64, U64]
  fun apply(input: U64): U64 =>
    input / 2

  fun name(): String => "Divide"

primitive OddFilter is Computation[U64, U64]
  fun apply(input: U64): (U64 | None) =>
    if ((input % 2) == 0) then
      input
    else
      None
    end

  fun name(): String => "OddFilter"

primitive DivideCountMax is Computation[CountMax, CountMax]
  fun apply(input: CountMax): CountMax =>
    CountMax(input.count, (input.max / 2))

  fun name(): String => "DivideCountMax"

primitive DoubleCountMax is Computation[CountMax, CountMax]
  fun apply(input: CountMax): CountMax =>
    CountMax(input.count, (input.max * 2))

  fun name(): String => "DoubleCountMax"
