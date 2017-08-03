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
        Application("single_stream-stateless_app")
          .new_pipeline[U64, U64]("U64 Double",
            TCPSourceConfig[U64].from_options(U64Decoder,
              TCPSourceConfigCLIParser(env.args)(0)))
            .to[U64]({(): Double => Double})
            .to_sink(TCPSinkConfig[U64].from_options(
              FramedU64Encoder,
              TCPSinkConfigCLIParser(env.args)(0)))
      end
      Startup(env, application, "single_stream-stateless_app")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
