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
        Application(
          "single_stream-uncoalesced-stateless_stateful_stateless_app")
          .new_pipeline[U64, U64](
            "Uncoalesced Stateless -> Stateful -> Stateless",
            TCPSourceConfig[U64].from_options(U64Decoder,
              TCPSourceConfigCLIParser(env.args)(0))
            where coalescing = false)
            .to[U64]({(): Double => Double})
            .to_stateful[U64 val, U64Counter](UpdateU64Counter,
              U64CounterBuilder, "u64-counter-builder")
            .to[U64]({(): Divide => Divide})
            .to_sink(TCPSinkConfig[U64].from_options(
              FramedU64Encoder,
              TCPSinkConfigCLIParser(env.args)(0)))
      end
      Startup(env, application,
        "single_stream-uncoalesced-stateless_stateful_stateless_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
