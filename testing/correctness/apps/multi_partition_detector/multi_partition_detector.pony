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
"""

use "debug"

// submodules
use t = "building_blocks"
use "inline_validation"
use "ring"
use "window_codecs"

//stdlib
use "assert"
use "buffered"
use "collections"
use "options"
use "serialise"
use "time"

// wallaroo/lib
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>

    try
      // Add options:
      //  "--depth": Int
      //  "--internal-source": flag
      //  "--partitions": Int
      var depth: USize = 1
      var gen_source: Bool = false
      var partition_count: USize = 40
      var cluster_initializer: Bool = false

      let options = Options(env.args, false)

      options.add("depth", "", I64Argument)
      options.add("gen-source", "", None)
      options.add("partitions", "", I64Argument)
      options.add("cluster-initializer", "", None)

      for option in options do
        match option
        | ("depth", let arg: I64) =>
          depth = arg.usize()
        | ("gen-source", None) =>
          gen_source = true
        | ("partitions", let arg: I64) =>
          partition_count = arg.usize()
        | ("cluster-initializer", None) =>
          cluster_initializer = true
        end
      end
      if not cluster_initializer then
        partition_count = 0
      end

      let pipeline = recover val
        var p = if gen_source then
          Wallaroo.source[t.Message]("Detector",
            GenSourceConfig[t.Message](
              MultiPartitionGeneratorBuilder(partition_count)))
        else
          Wallaroo.source[t.Message]("Detector",
            TCPSourceConfig[t.Message]
              .from_options(PartitionedU64FramedHandler,
                TCPSourceConfigCLIParser("Detector", env.args)?))
        end
        // Add as many layers of depth as specified in the `--depth` option
        for x in Range[USize](1, depth + 1) do
          env.out.print("Adding level " + x.string())
          p = p.key_by(WindowPartitionFunction)
          p = p.to[t.Message](TraceID(x.string()))
          p = p.to[t.Message](TraceWindow(x.string()))
        end
        p.to_sink(TCPSinkConfig[t.Message].from_options(MessageEncoder,
            TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "multi_partition_detector", pipeline)
    else
      env.out.print("Couldn't build topology!")
    end

class val MultiPartitionGeneratorBuilder
  let _partitions: USize

  new val create(partitions: USize) =>
    _partitions = partitions

  fun apply(): MultiPartitionGenerator =>
    MultiPartitionGenerator(_partitions)

// TODO: (optional) refactor this out of the detector code and add unit tests
// Use this with the internal source
class MultiPartitionGenerator
  let _partitions: USize

  new create(partitions: USize) =>
    _partitions = partitions

  fun initial_value(): (t.Message | None) =>
    if _partitions > 0 then
      t.Message("0", 1)
    else
      None
    end

  fun ref apply(v: t.Message): (t.Message | None) =>
    if _partitions > 0 then
      try
        let last_key = v.key().usize()?
        let last_value = v.value()
        let next_value =
          if (last_key + 1) == _partitions then
            last_value + 1
          else
            last_value
          end
        let next_key = (last_key + 1) % _partitions

        let m = t.Message(next_key.string(), next_value)

        // Print a timestamp
        ifdef debug then
            (let sec', let ns') = Time.now()
            let us' = ns' / 1000
            let ts' = PosixDate(sec', ns').format("%Y-%m-%d %H:%M:%S." + us'.string())
          @printf[I32]("%s Source decoded: %s\n".cstring(), ts'.cstring(),
            m.string().cstring())
        end

        consume m
      else
        Fail()
        t.Message("0", 1)
      end
    else
      None
    end

class WindowState is State
  var _window: t.Window = t.Window(t.WindowSize())
  var _key: String = ""

  fun string(): String =>
    try
      let data = _window.string(where fill = "0")?
      "(" + _key + "," + data + ")"
    else
      "Error: failed to convert sequence window into a string."
    end

  fun ref push(m: t.Message) =>
    match _key
    | "" => _key = m.key()
    | let k: String => if _key != m.key() then
      @printf[I32](("Error: trying to update the wrong partition. State key is"
        + " but messsage key is %s.\n").cstring(), _key, m.key())
      end
    end
    _window.push(m.value())

    let values: Array[U64] val = _window.to_array()
    try
      // Test validity of updated window
      Fact(IncrementsTest(values), "Increments test failed on " +
        m.string())?
    else
      Debug("failed values ...")
      Debug(values)
      ifdef "allow-invalid-state" then
        None
      else
        Fail()
      end
    end

  fun window(): t.Window val =>
    _window.clone()

class val TraceID is StatelessComputation[t.Message, t.Message]
  let _id: String
  let _name: String = "TraceID"

  new val create(s: String) =>
    _id = _name + "-" + s

  fun rekey(k: String): String =>
    k + "." + _id

  fun name(): String => "TraceID"

  fun apply(m: t.Message): t.Message =>
    ifdef debug then
      @printf[I32](("%s computing on key '%s' and value " +
        "'%s'\n").cstring(),
        _id.cstring(), m.key().cstring(), m.value().string().cstring())
    end
    t.Message(rekey(m.key()), m.value())

class val TraceWindow is StateComputation[t.Message, t.Message, WindowState]
  let _id: String
  let _name: String = "TraceWindow"

  new val create(s: String) =>
    _id = _name + "-" + s

  fun name(): String => _name

  fun rekey(k: String): String =>
    k + "." + _id

  fun apply(m: t.Message, state: WindowState): t.Message =>
    ifdef debug then
      @printf[I32](("%s computing on '%s' with state " +
        "'%s'\n").cstring(),
        _id.cstring(), m.string().cstring(), state.string().cstring())
    end

    state.push(m)

    t.Message(rekey(m.key()), state.window())

  fun initial_state(): WindowState =>
    WindowState
