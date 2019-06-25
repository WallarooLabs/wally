/*

Copyright 2019 The Wallaroo Authors.

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
use "ponytest"
// use "wallaroo_labs/logging"
use "lib:wallaroo-logging"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestFFI)

class iso _TestFFI is UnitTest
  fun name(): String => "logging/" + __loc.type_name()

  fun apply(h: TestHelper) /*?*/ =>
    let cat_40 = LogCategory(40)
    let cat_41 = LogCategory(41)
    let debug_40 = Log.make_sev_cat(Log.debug(), cat_40)
    let debug_41 = Log.make_sev_cat(Log.debug(), cat_41)

    Log.set_defaults()

    // Make it obvious if the log level changes
    h.assert_eq[U8](Log.info(), Log.default_severity())

    // Check for enabled sev+cat
    for sev in Range[U8](0, Log.info()) do
      for cat in Range[U8](0, Log.max_category()) do
        h.assert_eq[Bool](true, @l_enabled(sev, cat))
        h.assert_eq[Bool](true, @ll_enabled(Log.make_sev_cat(sev, cat)))
      end
    end

    // Check for disabled sev+cat
    for sev in Range[U8](Log.info() + 1, Log.max_severity() + 1) do
      for cat in Range[U8](0, Log.max_category()) do
        h.assert_eq[Bool](false, @l_enabled(sev, cat))
        h.assert_eq[Bool](false, @ll_enabled(Log.make_sev_cat(sev, cat)))
      end
    end

    @l(Log.crit(), cat_40, "Hello, %s, 1 of 3".cstring(), "everything".cstring())
    @ll(Log.make_sev_cat(Log.crit(), cat_40), "Hello, %s, 2 of 3".cstring(), "all".cstring())
    @ll(debug_40, "Error if this is printed!".cstring())

    // Now change the threshold for cat_40 only
    @w_set_severity_cat_threshold(Log.debug(), cat_40)
    @ll(debug_40, "Hello, %s, 3 of 3".cstring(), "all".cstring())
    @ll(debug_41, "Error if this is printed!".cstring())

    true
