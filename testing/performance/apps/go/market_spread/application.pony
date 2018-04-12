use "go_api"
use "wallaroo"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/sink/tcp_sink"
use wct = "wallaroo/core/topology"
use "wallaroo_labs/options"

use @WallarooApiSetArgs[None](argv: Pointer[Pointer[U8] tag] tag, argc: U64)

primitive ArgsToCArgs
  fun apply(args: Array[String] val): Array[Pointer[U8] tag] val =>
    let c_args = recover trn Array[Pointer[U8] tag] end
    for a in args.values() do
      c_args.push(a.cstring())
    end
    consume c_args

actor Main
  new create(env: Env) =>
    try
      var show_help: Bool = false

      let options = Options(WallarooConfig.application_args(env.args)?, false)
      options.add("help", "h", None)

      for option in options do
        match option
        | ("help", let arg: None) => show_help = true
        end
      end

      let c_args = ArgsToCArgs(options.remaining())
      @WallarooApiSetArgs(c_args.cpointer(), c_args.size().u64())
      let application_json_string = ApplicationSetup(show_help)

      try
        (let application, let application_name) = recover val
          BuildApplication.from_json(application_json_string, env, show_help)?
        end

        if show_help then
          StartupHelp()
          return
        end

        Startup(env, application, application_name)
      else
        @printf[I32]("Couldn't build topology\n".cstring())
      end
    end
