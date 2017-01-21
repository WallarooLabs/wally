"""
Setting up a complex app run (in order):
1) reports sink:
nc -l 127.0.0.1 7002 >> /dev/null

2) metrics sink:
nc -l 127.0.0.1 7003 >> /dev/null

3a) single worker
./arizona-source -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -n worker-name

3b) multi-worker
./arizona-source -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -t -n worker1
./arizona-source -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -n worker2
./arizona-source -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -n worker3

"""

use "lib:wallaroo"
use "lib:arizona-source-app"
use "lib:c++" if osx
use "lib:stdc++" if linux

use "collections"

use "wallaroo"
use "wallaroo/topology"
use "wallaroo/tcp-source"
use "wallaroo/cpp-api/pony"
use "debug"
use "options"

use @get_partition_key[KeyP](client_id: U64)
use @get_partition_function[PartitionFunctionP]()
use @get_source_decoder[SourceDecoderP]()
use @get_sink_encoder[SinkEncoderP]()
use @get_computation[ComputationP]()
use @get_state_computation[ComputationP]()
use @get_default_state_computation[ComputationP]()
use @get_state[StateP]()
use @get_default_state[StateP]()

primitive ArizonaStateBuilder
  fun name(): String => "state builder"
  fun apply(): CPPState =>
    // Debug("Building state")
    CPPState(@get_state())

primitive ArizonaDefaultStateBuilder
  fun name(): String => "default state builder"
  fun apply(): CPPState =>
    // Debug("Building state")
    CPPState(@get_default_state())

primitive Filter[In: Any val]
  fun name(): String => "filter"
  fun apply(r: In): None =>
    None

primitive FilterBuilder[In: Any val]
  fun apply(): Computation[In, In] val =>
    Filter[In]

primitive StateFilter[In: Any val] is StateComputation[In, None, String]
  fun name(): String => "statefilter"
  fun apply(msg: In,
    sc_repo: StateChangeRepository[String],
    state: String): (None, (StateChange[String] ref | None))
  =>
    match msg
    | let m: CPPData val => m.delete_obj()
    end
    (None, None)

  fun state_change_builders(): Array[StateChangeBuilder[String] val] val =>
    recover val
      Array[StateChangeBuilder[String] val]
    end

class val DataBuilder
  fun apply(): String => "FOO"
  fun name(): String => "FOO"

primitive StateFilterBuilder[In: Any val]
  fun apply(): StateComputation[In, None, String] val =>
    StateFilter[In]

actor Main
  var _clients: USize = 750
  new create(env: Env) =>
    var options = Options(env.args, false)
    options.add("clients", None, I64Argument)
    for option in options do
      match option
      | ("clients", let arg: I64) => _clients = arg.usize()
      end
    end
    @printf[I32]("Application has %u clients".cstring(), _clients)
    try
      let partition_function = recover val CPPPartitionFunctionU64(@get_partition_function()) end
      let partition_keys: Array[U64] val = partition_factory(10001, 10001 + _clients)
      let data_partition = Partition[CPPData val, U64](partition_function, partition_keys)

      let application = recover val
        Application("Arizona Topology")
          .new_pipeline[CPPData val, CPPData val]("source-decoder", recover CPPSourceDecoder(@get_source_decoder()) end)
            .to_state_partition[CPPData val, U64, CPPData val, CPPState](
              state_computation_factory(),
              ArizonaStateBuilder, "state-builder", data_partition
              where multi_worker = true, default_state_name = "default-state")
            .to_sink(recover CPPSinkEncoder(recover @get_sink_encoder() end) end, recover [0] end)
          .partition_default_target[CPPData val, CPPData val, CPPState](
            "Arizona Default Test", "default-state", state_computation_factory(),
            ArizonaDefaultStateBuilder)
      end
      Startup(env, application, "Arizona")
    else
      env.out.print("Could not build topology")
    end

  fun computation_factory(): CPPComputation val =>
    recover CPPComputation(recover @get_computation() end) end

  fun default_computation_factory(): CPPStateComputation val =>
    recover CPPStateComputation(recover @get_default_state_computation() end) end

  fun state_computation_factory(): CPPStateComputation val =>
    recover CPPStateComputation(recover @get_state_computation() end) end

  fun partition_factory(partition_start: USize, partition_end: USize): Array[U64] val =>
    let partition_count = partition_end - partition_start
    recover val
      let partitions = Array[U64 val](partition_count)
      for i in Range(partition_start, partition_end) do
        partitions.push(i.u64())
      end
      consume partitions
    end

class ComputationFactory
  fun apply(): Computation[CPPData val, CPPData val] val =>
    recover CPPComputation(recover @get_computation() end) end
