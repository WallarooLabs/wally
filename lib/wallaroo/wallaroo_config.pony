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
use "wallaroo_labs/mort"
use "wallaroo_labs/options"
use "wallaroo/core/spike"

class StartupOptions
  var m_arg: (Array[String] | None) = None
  var input_addrs: Map[String, (String, String)] val =
    recover input_addrs.create() end
  // var input_addrs: Array[Array[String]] val = recover Array[Array[String]] end
  var c_addr: Array[String] = [""; "0"]
  var c_host: String = ""
  var c_service: String = "0"
  var d_addr: Array[String] val = recover [""; "0"] end
  var d_host: String = ""
  var d_service: String = "0"
  var my_c_addr: Array[String] = [""; "0"]
  var my_c_host: String = ""
  var my_c_service: String = "0"
  var my_d_addr: Array[String] = [""; "0"]
  var my_d_host: String = ""
  var my_d_service: String = "0"
  var x_arg: (Array[String] | None) = None
  var worker_count: (USize | None) = None
  var is_initializer: Bool = false
  var worker_name: String = ""
  var resilience_dir: String = "/tmp"
  var log_rotation: Bool = false
  var do_local_file_io: Bool = true
  var use_io_journal: Bool = false
  var event_log_file_length: (USize | None) = None
  var j_arg: (Array[String] | None) = None
  var is_joining: Bool = false
  var a_arg: (String | None) = None
  var stop_the_world_pause: U64 = 2_000_000_000
  var checkpoints_enabled: Bool = true
  var time_between_checkpoints: U64 = 1_000_000_000
  var spike_config: (SpikeConfig | None) = None
  var run_with_resilience: Bool = false
  var dos_servers: Array[(String,String)] val = recover dos_servers.create() end

primitive WallarooConfig
  fun application_args(args: Array[String] val): Array[String] val ? =>
    (let z, let remaining) = _parse(args where handle_help = false)?
    remaining

  fun wallaroo_args(args: Array[String] val): StartupOptions ? =>
    (let so, let z) = _parse(args where handle_help = true)?
    so

  fun wactor_args(args: Array[String] val): StartupOptions ? =>
    // The wactor system expects to get input addresses from this function,
    // Wallaroo expects applications to parse this information themselves.
    (let so, let z) = _parse(args where handle_help = true,
      include_input_addrs = true)?
    so

  fun _parse(args: Array[String] val, handle_help: Bool,
    include_input_addrs: Bool = true): (StartupOptions, Array[String] val) ?
  =>
    let so: StartupOptions ref = StartupOptions

    var spike_seed: (U64 | None) = None
    var spike_drop: Bool = false
    var spike_prob: (F64 | None) = None
    var spike_margin: (USize | None) = None

    var options = Options(args, false)

    options
      .add("metrics", "m", StringArgument)
      .add("control", "c", StringArgument)
      .add("data", "d", StringArgument)
      .add("my-control", "x", StringArgument)
      .add("my-data", "y", StringArgument)
      .add("external", "e", StringArgument)
      .add("file", "f", StringArgument)
      // worker count includes the initial "leader" since there is no
      // persisting leader
      .add("worker-count", "w", I64Argument)
      .add("cluster-initializer", "t", None)
      .add("name", "n", StringArgument)
      .add("resilience-dir", "r", StringArgument)
      .add("resilience-dos-server", "", StringArgument)
      .add("resilience-no-local-file-io", "", None)
      .add("resilience-enable-io-journal", "", None)
      .add("run-with-resilience", "", None)
      .add("log-rotation", "", None)
      .add("event-log-file-size", "l", I64Argument)
      // pass in control address of any worker as the value of this parameter
      // to join a running cluster
      .add("join", "j", StringArgument)
      .add("stop-pause", "u", I64Argument)
      .add("spike-seed", "", I64Argument)
      .add("spike-drop", "", None)
      .add("spike-prob", "", F64Argument)
      .add("spike-margin", "", I64Argument)
      .add("time-between-checkpoints", "", I64Argument)

    if handle_help then
      options.add("help", "h", None)
    end

    if include_input_addrs then
      options.add("in", "i", StringArgument)
    end

    for option in options do
      match option
      | ("help", let arg: None) =>
        StartupHelp()
      | ("metrics", let arg: String) =>
        so.m_arg = arg.split(":")
      | ("in", let arg: String) =>
        let input_addrs_trn = recover trn Map[String, (String, String)] end
        for input_address in arg.split(",").values() do
          let source_and_address = input_address.split("@")
          let address_data = source_and_address(1)?.split(":")
          input_addrs_trn.update(source_and_address(0)?,
            (address_data(0)?, address_data(1)?))
        end
        so.input_addrs = consume input_addrs_trn
      | ("control", let arg: String) =>
        so.c_addr = arg.split(":")
        so.c_host = so.c_addr(0)?
        so.c_service = so.c_addr(1)?
      | ("data", let arg: String) =>
        let d_addr_ref = arg.split(":")
        let d_addr_trn = recover trn Array[String] end
        d_addr_trn.push(d_addr_ref(0)?)
        d_addr_trn.push(d_addr_ref(1)?)
        so.d_addr = consume d_addr_trn
        so.d_host = so.d_addr(0)?
        so.d_service = so.d_addr(1)?
      | ("my-control", let arg: String) =>
        so.my_c_addr = arg.split(":")
        so.my_c_host = so.my_c_addr(0)?
        so.my_c_service = so.my_c_addr(1)?
      | ("my-data", let arg: String) =>
        so.my_d_addr = arg.split(":")
        so.my_d_host = so.my_d_addr(0)?
        so.my_d_service = so.my_d_addr(1)?
      | ("external", let arg: String) =>
        so.x_arg = arg.split(":")
      | ("worker-count", let arg: I64) =>
        if arg.usize() == 0 then
          FatalUserError("--worker-count must be at least 1.")
        end
        so.worker_count = arg.usize()
      | ("cluster-initializer", None) =>
        so.is_initializer = true
      | ("name", let arg: String) =>
        so.worker_name = arg
      | ("resilience-dir", let arg: String) =>
        if arg.substring(arg.size().isize() - 1) == "/" then
          @printf[I32]("--resilience-dir must not end in /\n".cstring())
          error
        else
          so.resilience_dir = arg
        end
      | ("resilience-dos-server", let arg: String) =>
        let dos_servers: Array[(String,String)] trn = recover dos_servers.create() end
        for s in arg.split(",").values() do
          let h_s = s.split(":")
          dos_servers.push((h_s(0)?, h_s(1)?))
        end
        so.dos_servers = consume dos_servers
      | ("resilience-no-local-file-io", let arg: None) =>
        so.do_local_file_io = false
      | ("resilience-enable-io-journal", let arg: None) =>
        so.use_io_journal = true
      | ("run-with-resilience", let arg: None) =>
        so.run_with_resilience = true
      | ("log-rotation", let arg: None) => so.log_rotation = true
      | ("event-log-file-size", let arg: I64) =>
        so.event_log_file_length = arg.usize()
      | ("join", let arg: String) =>
        so.j_arg = arg.split(":")
        so.is_joining = true
      | ("stop-pause", let arg: I64) =>
        so.stop_the_world_pause = arg.u64()
      | ("spike-seed", let arg: I64) =>
        spike_seed = arg.u64()
      | ("spike-drop", None) =>
        spike_drop = true
      | ("spike-prob", let arg: F64) =>
        spike_prob = arg
      | ("spike-margin", let arg: I64) =>
        spike_margin = arg.usize()
      | ("time-between-checkpoints", let arg: I64) =>
        so.time_between_checkpoints = arg.u64()
      end
    end

    if so.is_joining and so.is_initializer then
      @printf[I32](("--cluster-initializer is an invalid command line " +
        "argument when joining.  Joining worker cannot function as " +
        "initializer.\n").cstring())
      error
    end

    if so.is_initializer then
      match so.worker_count
      | None =>
        so.worker_count = 1
      | let wc: USize =>
        ifdef not "clustering" then
          if wc > 1 then
            FatalUserError("Worker counts greater than 1 are only supported " +
              "in clustering mode")
          end
        end
      end
      so.worker_name = "initializer"
      if so.d_host == "" then
        FatalUserError("Cluster initializer needs its data channel address " +
          "to be specified via --data.")
      end
    elseif so.is_joining then
      match so.worker_count
      | None =>
        so.worker_count = 1
      end
    else
      match so.worker_count
      | let wc: USize =>
        FatalUserError("Only supply --worker-count to cluster initializer " +
          "or to joining worker.")
      end
      if so.d_host != "" then
        FatalUserError("Only supply --data to cluster initializer.")
      end
    end

    if (not so.is_initializer and (so.dos_servers.size() > 0)) and
      ((so.my_d_host == "") or (so.my_c_host == "")) then
        FatalUserError("Non-initializer nodes must specify --my-control and " +
          " --my-data flags")
    end

    ifdef "resilience" then
      if not so.run_with_resilience then
        FatalUserError("You are running a resilience-enabled binary. " +
          "You must pass in the command line flag `--run-with-resilience`.")
      end
    else
      if so.run_with_resilience then
        FatalUserError("You are running a resilience-disabled binary. " +
          "You cannot run with the command line flag `--run-with-resilience`.")
      end
    end

    ifdef "spike" then
      so.spike_config = SpikeConfig(spike_drop, spike_prob, spike_margin,
        spike_seed)?
      let sc = so.spike_config as SpikeConfig

      @printf[I32](("|||Spike seed: " + sc.seed.string() +
        "|||\n").cstring())
      @printf[I32](("|||Spike drop: " + sc.drop.string() +
        "|||\n").cstring())
      @printf[I32](("|||Spike prob: " + sc.prob.string() +
        "|||\n").cstring())
      @printf[I32](("|||Spike margin: " + sc.margin.string() +
        "|||\n").cstring())
    end

    (so, options.remaining())
