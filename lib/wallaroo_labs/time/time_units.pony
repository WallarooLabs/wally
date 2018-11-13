/*

Copyright 2018 The Wallaroo Authors.

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

primitive Nanoseconds
  fun apply(x: USize): U64 =>
    """
    Return in nanoseconds
    """
    x.u64()

primitive Microseconds
  fun apply(x: USize): U64 =>
    """
    Return in nanoseconds
    """
    Nanoseconds(x) * 1_000

primitive Milliseconds
  fun apply(x: USize): U64 =>
    """
    Return in nanoseconds
    """
    Microseconds(x) * 1_000

primitive Seconds
  fun apply(x: USize): U64 =>
    """
    Return in nanoseconds
    """
    Milliseconds(x) * 1_000

primitive Minutes
  fun apply(x: USize): U64 =>
    """
    Return in nanoseconds
    """
    Seconds(x) * 60

primitive Hours
  fun apply(x: USize): U64 =>
    """
    Return in nanoseconds
    """
    Minutes(x) * 60

