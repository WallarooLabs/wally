use "wallaroo"
use "wallaroo/generic_app_components"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("single_stream-uncoalesced-stateless_app")
          .new_pipeline[U64, U64]("Uncoalesced Stateless",
            U64Decoder where coalescing = false)
            .to[U64]({(): Double => Double})
            .to_sink(FramedU64Encoder, recover [0] end)
      end
      Startup(env, application, "single_stream-uncoalesced-stateless_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
