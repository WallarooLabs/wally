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

// wallaroo/lib
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>

    try
      // Add "--depth" option
      var depth: USize = 1
      let options = Options(env.args, false)

      options.add("depth", "", I64Argument)

      for option in options do
        match option
        | ("depth", let arg: I64) =>
          depth = arg.usize()
        end
      end

      // Still requires passing an array here... even though it's empty
      let partition = Partitions[t.Message](WindowPartitionFunction, [])

      let application = recover val
        let a = Application("Multi Partition Detector")
        let p = a.new_pipeline[t.Message, String]("Detector",
          TCPSourceConfig[t.Message].from_options(PartitionedU64FramedHandler,
            TCPSourceConfigCLIParser(env.args)?(0)?))
        // Add as many layers of depth as specified in the `--depth` option
        for x in Range[USize](1, depth + 1) do
          env.out.print("Adding level " + x.string())
          p.to[t.Message]({(): TraceID => TraceID(x.string())})
          p.to_state_partition[t.Message, t.Message,
            WindowState](TraceWindow(x.string()), WindowStateBuilder,
            "state" + x.string(),
            partition where multi_worker = true)
        end
        p.to_sink(TCPSinkConfig[t.Message].from_options(MessageEncoder,
            TCPSinkConfigCLIParser(env.args)?(0)?))
        consume a
      end
      Startup(env, application, "Multi Partition Detector")
    else
      env.out.print("Couldn't build topology!")
    end

class val WindowStateBuilder
  fun apply(): WindowState => WindowState
  fun name(): String => "Window State"

class WindowState is State
  var _window: t.Window = t.Window(t.WindowSize())
  var _key: String = ""

  fun string(): String =>
    try
      _window.string(where fill = "0")?
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

class val TraceID is Computation[t.Message, t.Message]
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

  fun apply(m: t.Message,
    sc_repo: StateChangeRepository[WindowState],
    state: WindowState): (t.Message, DirectStateChange)
  =>
    state.push(m)

    ifdef debug then
      @printf[I32](("%s computing on key '%s' and value " +
        "'%s'\n").cstring(),
        _id.cstring(), m.key().cstring(), state.string().cstring())
    end

    (t.Message(rekey(m.key()), state.window()), DirectStateChange)

  fun state_change_builders():
    Array[StateChangeBuilder[WindowState]] val
  =>
    recover Array[StateChangeBuilder[WindowState]] end
