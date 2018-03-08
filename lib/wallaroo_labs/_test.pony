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

"""
# Wallaroo Labs Standard Library

This package represents the unit test suite for Wallaroo Labs's
standard library. Classes herein are used across applications rather
than being specific to just Wallaroo.

All tests can be run by compiling and running this package.
"""
use "ponytest"
use bytes = "bytes"
use container_queue = "container_queue"
use fix = "fix"
use math = "math"
use messages = "messages"
use options = "options"
use queue = "queue"
use weighted = "weighted"
use query = "query"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    bytes.Main.make().tests(test)
    container_queue.Main.make().tests(test)
    fix.Main.make().tests(test)
    math.Main.make().tests(test)
    messages.Main.make().tests(test)
    options.Main.make().tests(test)
    queue.Main.make().tests(test)
    weighted.Main.make().tests(test)
    query.Main.make().tests(test)
