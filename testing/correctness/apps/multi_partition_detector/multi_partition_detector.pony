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
// submodules
use t = "building_blocks"
use "inline_validation"
use "ring"
use "window_codecs"

//stdlib
use "assert"
use "buffered"
use "collections"
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

/*
TODO:
- Use Options package to allow users to choose depth
*/

actor Main
  new create(env: Env) =>

    try
      // Still requires passing an array here...
      let partition = Partition[t.Message](WindowPartitionFunction, [])

      let tid1 = TraceID("1")
      let tid2 = TraceID("2")
      let tw1 = TraceWindow("1")
      let tw2 = TraceWindow("2")
      let application = recover val
        Application("Multi Partition Detector")
          .new_pipeline[t.Message, String]("Detector",
            TCPSourceConfig[t.Message].from_options(PartitionedU64FramedHandler,
              TCPSourceConfigCLIParser(env.args)?(0)?))
          .to[t.Message]({(): TraceID => tid1})
          .to_state_partition[t.Message, t.Message,
            WindowState](tw1, WindowStateBuilder, "state1",
              partition where multi_worker = true)
          .to[t.Message]({(): TraceID => tid2})
          .to_state_partition[t.Message, t.Message,
            WindowState](tw2, WindowStateBuilder, "state2",
              partition where multi_worker = true)
          .to_sink(TCPSinkConfig[t.Message].from_options(MessageEncoder,
              TCPSinkConfigCLIParser(env.args)?(0)?))
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

    try
      // Test validity of updated window
      let values = _window.to_array()
      Fact(IncrementsTest(consume values), "Increments test failed on " +
        m.string())?
    else
      Fail()
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
