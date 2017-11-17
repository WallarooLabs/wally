use "debug"
use "go_api"
use "wallaroo"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/sink/tcp_sink"
use wct = "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    let application_json_string = ApplicationSetup()
    Debug(application_json_string)

    try
      let application = recover val
        BuildApplication.from_json(application_json_string, env)?
      end

      Startup(env, application, "kafka-reverse")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
