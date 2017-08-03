use "collections"
use "signals"
use "sendence/options"
use "wallaroo"
use "wallaroo/tcp_source"
use "wallaroo/tcp_sink"
use "wallaroo/topology"

use "lib:python2.7"
use "lib:python-wallaroo"

actor Main
  new create(env: Env) =>
    Machida.start_python()

    try
      SignalHandler(ShutdownHandler, Sig.int())

      var module_name: String = ""

      let options = Options(WallarooConfig.application_args(env.args), false)
      options.add("application-module", "", StringArgument)

      for option in options do
        match option
        | ("application-module", let arg: String) => module_name = arg
        end
      end

      try
        let module = Machida.load_module(module_name)

        try
          Machida.set_user_serialization_fns(module)
          let application_setup =
            Machida.application_setup(module, options.remaining())
          let application = recover val
            let tcp_sources = TCPSourceConfigCLIParser(env.args)
            let tcp_sinks = TCPSinkConfigCLIParser(env.args)
            Machida.apply_application_setup(application_setup, tcp_sources, tcp_sinks)
          end
          Startup(env, application, module_name)
        else
          @printf[I32]("Something went wrong while building the application\n"
            .cstring())
        end
      else
        @printf[I32](("Could not load module '" + module_name + "'\n")
          .cstring())
      end
    else
      @printf[I32]((
        "Please use `--application-module=MODULE_NAME` to specify " +
        "an application module\n").cstring())
    end
