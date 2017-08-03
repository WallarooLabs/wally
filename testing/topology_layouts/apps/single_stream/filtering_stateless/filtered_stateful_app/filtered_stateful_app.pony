use "wallaroo"
use "wallaroo/generic_app_components"
use "wallaroo/source"
use "wallaroo/tcp_sink"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("Single Stream Stateless: Double App")
          .new_pipeline[U64, U64]("U64 Double",
            TCPSourceConfig[U64].from_options(U64Decoder,
              TCPSourceConfigCLIParser(env.args)(0)))
            .to[U64]({(): OddFilter => OddFilter})
            .to_stateful[U64 val, U64Counter](UpdateU64Counter,
              U64CounterBuilder, "u64-counter-builder")
          .to_sink(TCPSinkConfig[U64].from_options(
              FramedU64Encoder,
              TCPSinkConfigCLIParser(env.args)(0)))
      end
      Startup(env, application, "single-stream-stateless")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
