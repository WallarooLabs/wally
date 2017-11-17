use "go_api"
use "wallaroo"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/sink/tcp_sink"
use wct = "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    let application_json_string = ApplicationSetup()

    try
      // let letter_partition = wct.Partition[GoData, U64](
      //   PartitionFunctionU64(6), PartitionListU64(7))

      // let application = recover val
      //   Application("word count")
      //     .new_pipeline[GoData, GoData]("word count",
      //       TCPSourceConfig[GoData].from_options(GoDecoder(1),
      //         TCPSourceConfigCLIParser(env.args)?(0)?))
      //       .to[GoData](ComputationMultiBuilder(2))

      //       .to_state_partition[GoData, U64, GoData, GoState](StateComputation(4),
      //         StateBuilder(3), "word-count", letter_partition
      //         where multi_worker = true)

      //       .to_sink(TCPSinkConfig[GoData].from_options(GoEncoder(5),
      //         TCPSinkConfigCLIParser(env.args)?(0)?))?
      //  end

      let application = recover val
        BuildApplication.from_json(application_json_string, env)?
      end

      Startup(env, application, "word-count")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
