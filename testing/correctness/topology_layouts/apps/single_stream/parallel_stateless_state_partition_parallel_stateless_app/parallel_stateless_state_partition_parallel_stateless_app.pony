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
Topology Layout Integration Test

This is a test application to verify that the following topology layout compiles and runs for 1-3 workers. The included Makefile will run an integration test with a given input and an expected output to verify results. Those tests are run as part of CI.

Single Stream to Single Sink
Single Pipeline
Parallel Stateless Computation
State Partition (there will be three partitions)
Parallel Stateless Computation
"""

use "generic_app_components"
use "wallaroo"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    try

      // This is basically the same as applying mod 2 before a double
      // computation
      let mod6partition = Partitions[U64](
        Mod6PartitionFunction, recover ["0"; "2"; "4"] end)

      let application = recover val
        Application("single_stream-parallel_stateless_state_partition_parallel_stateless_app")
          .new_pipeline[U64, U64]("U64 Double CountAndMax DivideCountMax",
            TCPSourceConfig[U64].from_options(U64Decoder,
              TCPSourceConfigCLIParser(env.args)?(0)?))
            .to_parallel[U64]({(): Double => Double})
            .to_state_partition[U64, CountMax, CountAndMax](
              UpdateCountAndMax, CountAndMaxBuilder,
              "count-and-max",
              mod6partition where multi_worker = true)
            .to_parallel[CountMax]({(): DivideCountMax => DivideCountMax})
            .to_sink(TCPSinkConfig[CountMax].from_options(
              FramedCountMaxEncoder,
              TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Startup(env, application,
        "single_stream-parallel_stateless_state_partition_parallel_stateless_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
