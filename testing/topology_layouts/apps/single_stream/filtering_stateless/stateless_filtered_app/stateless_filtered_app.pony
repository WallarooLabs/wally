use "wallaroo"
use "wallaroo/topology"
use "wallaroo/generic_app_components"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("single_stream-filtering_stateless-stateless_filter_app")
          .new_pipeline[U64, U64]("U64 Double", U64Decoder)
            .to[U64]({(): Double => Double})
            .to[U64]({(): OddFilter => OddFilter})
          .to_sink(FramedU64Encoder, recover [0] end)
      end
      Startup(env, application,
        "single_stream-filtering_stateless-stateless_filter_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
