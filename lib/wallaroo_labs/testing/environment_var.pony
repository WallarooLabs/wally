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

primitive EnvironmentVar

  fun get(k: String, default: String = ""): String ref =>
    """
    Wrapper around FFI call to getenv(3) with default string.
    """
    let ptr = @getenv[Pointer[U8]](k.cstring())

    if ptr.is_null() then
      default.clone()
    else
      String.from_cstring(ptr)
    end

  fun get2(p1: String, p2: String,
    join: String = "_", default: String = ""): String ref =>
    """
    Wrapper around FFI call to getenv(3) with quasi-hierarchical
    variable naming scheme.  An example call of
    get2("TEST", "FOO" where join = "_") will return the
    value of the first environment variable in the following list:
      1. TEST_FOO
      2. TEST

    If none are found, then the default string is returned.
    """
    let not_found: String = not_found_val()
    let k = p1 + join + p2

    match get(k, not_found)
    | not_found =>
      match get(p1, default)
      | not_found =>
        default.clone()
      | let s: String ref =>
        s
      end
    | let s: String ref =>
      s
    end

  fun get3(p1: String, p2: String, p3: String,
    join: String = "_", default: String = ""): String ref =>
    """
    Wrapper around FFI call to getenv(3) with quasi-hierarchical
    variable naming scheme.  An example call of
    get2("TEST", "FOO", "BAR" where join = "_") will return the
    value of the first environment variable in the following list:
      1. TEST_FOO_BAR
      2. TEST_FOO
      3. TEST

    If none are found, then the default string is returned.
    """
    let not_found: String = not_found_val()
    let k = p1 + join + p2 + join + p3

    match get(k, not_found)
    | not_found =>
      match get2(p1, p2, join, default)
      | not_found =>
        default.clone()
      | let s: String ref =>
        s
      end
    | let s: String ref =>
      s
    end

    fun not_found_val(): String =>
      "\\$\\$\\$\\$$$$$$\\$|$|$|$|$"