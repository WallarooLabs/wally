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
Partitioned Stateful Computation -> Stateless Computation
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

      let powers_of_2_partition = Partitions[U64](
        PowersOfTwoPartitionFunction, PowersOfTwo())

      let application = recover val
        Application("Next Power of 2 U64 Counter App")
          .new_pipeline[U64, U64]("U64 Counter",
            TCPSourceConfig[U64].from_options(U64Decoder,
              TCPSourceConfigCLIParser(env.args)?(0)?))
            .to_state_partition[U64, U64Counter](
              UpdateU64Counter, U64CounterBuilder,
              "counter-state",
              powers_of_2_partition where multi_worker = true)
            .to[U64]({(): Double => Double})
            .to_sink(TCPSinkConfig[U64].from_options(
              FramedU64Encoder,
              TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Startup(env, application, "single-stream-stateful")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
