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

use "ponybench"
use "../../logging"

use @printf[I32](fmt: Pointer[U8] tag, ...)
use @l_enabled[Bool](severity: LogSeverity, category: LogCategory)
use @ll_enabled[Bool](sev_cat: U16)
use @l[I32](severity: LogSeverity, category: LogCategory, fmt: Pointer[U8] tag, ...)
use @ll[I32](sev_cat: U16, fmt: Pointer[U8] tag, ...)

actor Main is BenchmarkList
  new create(env: Env) =>
    PonyBench(env, this)

  fun tag benchmarks(bench: PonyBench) =>
    bench(_True)
    bench(_TrueWithoutDoNotOptimize)
    bench(_CheckLEnabled)
    bench(_CheckLEnabled3)
    bench(_CheckLNotEnabled)
    bench(_CheckLLEnabled)
    bench(_CheckLLNotEnabled)

class iso _True is MicroBenchmark
  fun name(): String =>
    __loc.type_name()

  fun ref before() =>
    Log.set_defaults()

  fun ref apply() =>
    DoNotOptimise[Bool](@_w_true[Bool]())

class iso _TrueWithoutDoNotOptimize is MicroBenchmark
  fun name(): String =>
    __loc.type_name()

  fun ref before() =>
    Log.set_defaults()

  fun ref apply() =>
    @_w_true[Bool]()

class iso _CheckLEnabled is MicroBenchmark
  fun name(): String =>
    __loc.type_name()

  fun ref before() =>
    Log.set_defaults()

  fun ref apply() =>
    DoNotOptimise[Bool](@l_enabled(Log.info(), Log.checkpoint()))

class iso _CheckLEnabled3 is MicroBenchmark
  fun name(): String =>
    __loc.type_name()

  fun ref before() =>
    Log.set_defaults()

  fun ref apply() =>
    DoNotOptimise[Bool](@l_enabled(Log.info(), Log.checkpoint()))
    DoNotOptimise[Bool](@l_enabled(Log.warn(), Log.checkpoint()))
    DoNotOptimise[Bool](@l_enabled(Log.crit(), Log.checkpoint()))

class iso _CheckLNotEnabled is MicroBenchmark
  fun name(): String =>
    __loc.type_name()

  fun ref before() =>
    Log.set_defaults()

  fun ref apply() =>
    DoNotOptimise[Bool](@l_enabled(Log.debug(), Log.checkpoint()))

class iso _CheckLLEnabled is MicroBenchmark
  let _info_cp: U16 = Log.make_sev_cat(Log.info(), Log.checkpoint())

  fun name(): String =>
    __loc.type_name()

  fun ref before() =>
    Log.set_defaults()

  fun ref apply() =>
    DoNotOptimise[Bool](@ll_enabled(_info_cp))

class iso _CheckLLNotEnabled is MicroBenchmark
  let _debug_cp: U16 = Log.make_sev_cat(Log.debug(), Log.checkpoint())

  fun name(): String =>
    __loc.type_name()

  fun ref before() =>
    Log.set_defaults()

  fun ref apply() =>
    DoNotOptimise[Bool](@ll_enabled(_debug_cp))
