"""
Topology Layout Integration Test

This is a test application to verify that the following topology layout compiles and runs for 1-3 workers. The included Makefile will run an integration test with a given input and an expected output to verify results. Those tests are run as part of CI.

Single Stream to Single Sink
Single Pipeline
Stateless Computation -> Filtered Stateless Computation
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
      let application = recover val
        Application("single_stream-filtering_stateless-stateless_filter_app")
          .new_pipeline[U64, U64]("U64 Double",
            TCPSourceConfig[U64].from_options(U64Decoder,
              TCPSourceConfigCLIParser(env.args)(0)))
            .to[U64]({(): Double => Double})
            .to[U64]({(): OddFilter => OddFilter})
          .to_sink(TCPSinkConfig[U64].from_options(
              FramedU64Encoder,
              TCPSinkConfigCLIParser(env.args)(0)))
      end
      Startup(env, application,
        "single_stream-filtering_stateless-stateless_filter_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
