"""
Setting up a complex app run (in order):
1) reports sink:
nc -l 127.0.0.1 7002 >> /dev/null

2) metrics sink:
nc -l 127.0.0.1 7003 >> /dev/null

3a) single worker counter app:
./counter-app -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -n worker-name

3b) multi-worker complex app:
./counter-app -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -t -n worker1
./counter-app -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -n worker2
./counter-app -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -n worker3

Incoming messages:
[size] -- how many bytes to follow, 16-bit big endian
[count] -- how many integers to follow, 16-bit big endian
[value1] -- value 1, 32-bit big endian
...
[valueN] -- value N, 32-bit big endian

Outgoing messages:
[total] -- total count so far, 32-bit big endian

To send a message:

`echo -n '\0\012\0\02\0\0\03\01\0\0\0\03' | nc 127.0.0.1 7010`
"""

use "lib:wallaroo"
use "lib:counter-app"
use "lib:c++"

use "buffered"
use "wallaroo"
use "wallaroo/topology"
use "wallaroo/tcp-source"
use "wallaroo/cpp-api/pony"
use "debug"

use @get_source_decoder[SourceDecoderP]()
use @get_sink_encoder[SinkEncoderP]()
use @get_computation[ComputationP]()
use @get_state_computation[ComputationP]()
use @get_dummy_computation[ComputationP]()
use @get_state[StateP]()

primitive StateComputationFactory
  fun apply(): CPPStateComputation val =>
    Debug("Building state computation")
    recover CPPStateComputation(recover CPPManagedObject(@get_state_computation()) end) end

primitive DummyComputationFactory
  fun apply(): CPPStateComputation val =>
    Debug("Building dummy computation")
    recover CPPStateComputation(recover CPPManagedObject(@get_dummy_computation()) end) end

primitive ComputationFactory0
  fun apply(): CPPComputation val =>
    Debug("Building computation")
    recover CPPComputation(recover CPPManagedObject(@get_computation()) end) end

primitive ComputationFactory1
  fun apply(): CPPComputation val =>
    Debug("Building computation")
    recover CPPComputation(recover CPPManagedObject(@get_computation()) end) end

primitive ComputationFactory2
  fun apply(): CPPComputation val =>
    Debug("Building computation")
    recover CPPComputation(recover CPPManagedObject(@get_computation()) end) end

primitive AccumulatorStateBuilder
  fun name(): String => "accumulator state builder"
  fun apply(): CPPState =>
    Debug("Building state")
    CPPState(CPPManagedObject(@get_state()))

primitive SimplePartitionFunction
  fun apply(input: CPPData val): U64
  =>
    input.partition_index()

class LegalSymbols
  let symbols: Array[U64] val

  new create() =>
    symbols = recover [0] end

actor Main
  new create(env: Env) =>
    try
      let cpp_data_partition = Partition[CPPData val, U64](
        SimplePartitionFunction, LegalSymbols.symbols)
      let application = recover val
        Application("Passthrough Topology")
          .new_pipeline[CPPData val, CPPData val]("source decoder", recover CPPSourceDecoder(recover CPPManagedObject(@get_source_decoder()) end) end
            where coalescing = false)
          // .to_stateful[CPPData val, CPPState](
          //   StateComputationFactory(),
          //   AccumulatorStateBuilder, "accumulator-builder")
          .to_state_partition[CPPData val, U64, CPPData val, CPPState](
            DummyComputationFactory(),
            AccumulatorStateBuilder, "accumulator-builder", cpp_data_partition)
          .to[CPPData val](ComputationFactory0)
          .to[CPPData val](ComputationFactory1)
          .to[CPPData val](ComputationFactory2)
          //.to_state_partition[CPPData val](ComputationFactory1)
          .to_sink(recover CPPSinkEncoder(recover CPPManagedObject(@get_sink_encoder()) end) end, recover [0] end)
      end
      Startup(env, application, None)
    else
      env.out.print("Could not build topology")
    end
