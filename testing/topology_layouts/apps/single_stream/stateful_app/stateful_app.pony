use "wallaroo"
use "wallaroo/topology"
use "wallaroo/generic_app_components"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("single_stream-stateful_app")
          .new_pipeline[U64, U64]("U64 Counter", U64Decoder)
            .to_stateful[U64 val, U64Counter](UpdateU64Counter,
              U64CounterBuilder, "u64-counter-builder")
            .to_sink(FramedU64Encoder, recover [0] end)
      end
      Startup(env, application, "single_stream-stateful_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
