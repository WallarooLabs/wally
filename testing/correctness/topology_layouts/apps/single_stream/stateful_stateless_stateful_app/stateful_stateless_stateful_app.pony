"""
Topology Layout Integration Test

This is a test application to verify that the following topology layout compiles and runs for 1-3 workers. The included Makefile will run an integration test with a given input and an expected output to verify results. Those tests are run as part of CI.

Single Stream to Single Sink
Single Pipeline
Stateful Computation -> Stateless Computation -> Stateful Computation
"""

use "generic_app_components"
use "wallaroo"
use "wallaroo/source"
use "wallaroo/sink/tcp_sink"
use "wallaroo/source/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("single_stream-stateful_stateless_stateful_app")
          .new_pipeline[U64, U64]("Stateful -> Stateless -> Stateful",
            TCPSourceConfig[U64].from_options(U64Decoder,
              TCPSourceConfigCLIParser(env.args)(0)))
            .to_stateful[U64 val, U64Counter](UpdateU64Counter,
              U64CounterBuilder, "u64-counter-builder")
            .to[U64]({(): Double => Double})
            .to_stateful[U64 val, U64Counter](UpdateU64Counter,
              U64CounterBuilder, "u64-counter-builder")
            .to_sink(TCPSinkConfig[U64].from_options(
              FramedU64Encoder,
              TCPSinkConfigCLIParser(env.args)(0)))
      end
      Startup(env, application,
        "single_stream-stateful_stateless_stateful_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
