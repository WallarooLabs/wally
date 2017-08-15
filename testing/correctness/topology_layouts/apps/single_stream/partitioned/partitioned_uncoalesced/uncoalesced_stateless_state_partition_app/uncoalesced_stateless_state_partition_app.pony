"""
Topology Layout Integration Test

This is a test application to verify that the following topology layout compiles and runs for 1-3 workers. The included Makefile will run an integration test with a given input and an expected output to verify results. Those tests are run as part of CI.

Single Stream to Single Sink
Single Pipeline
Coalescing Off
Stateless Computation -> Partitioned Stateful Computation
"""

use "generic_app_components"
use "wallaroo"
use "wallaroo/source"
use "wallaroo/tcp_sink"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try

      let powers_of_2_partition = Partition[U64, U64](
        PowersOfTwoPartitionFunction, PowersOfTwo())

      let application = recover val
        Application(
          "single_stream-partitioned-uncoalesced-stateless_state_partition_app")
          .new_pipeline[U64, U64](
            "Uncoalesced -> Stateless -> State Partition",
            TCPSourceConfig[U64].from_options(U64Decoder,
              TCPSourceConfigCLIParser(env.args)(0))
            where coalescing = false)
            .to[U64]({(): Double => Double})
            .to_state_partition[U64 val, U64 val, U64, U64Counter](
              UpdateU64Counter, U64CounterBuilder,
              "counter-state",
              powers_of_2_partition where multi_worker = true)
            .to_sink(TCPSinkConfig[U64].from_options(
              FramedU64Encoder,
              TCPSinkConfigCLIParser(env.args)(0)))
      end
      Startup(env, application,
        "single_stream-partitioned-uncoalesced-stateless_state_partition_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
