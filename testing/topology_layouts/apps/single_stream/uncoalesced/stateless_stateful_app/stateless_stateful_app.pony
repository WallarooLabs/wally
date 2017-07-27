use "wallaroo"
use "wallaroo/generic_app_components"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("single_stream-uncoalesced-stateless_stateful_app")
          .new_pipeline[U64, U64]("Uncoalesced Stateless -> Stateful",
            U64Decoder where coalescing = false)
            .to[U64]({(): Double => Double})
            .to_stateful[U64 val, U64Counter](UpdateU64Counter,
              U64CounterBuilder, "u64-counter-builder")
            .to_sink(FramedU64Encoder, recover [0] end)
      end
      Startup(env, application,
        "single_stream-uncoalesced-stateless_stateful_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
