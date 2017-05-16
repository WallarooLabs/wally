use "collections"
use "signals"
use "sendence/options"
use "wallaroo"
use "wallaroo/tcp_source"
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
          let application_setup =
            Machida.application_setup(module, options.remaining())
          let application = recover val
            Machida.apply_application_setup(application_setup)
          end
          Startup(env, application, None)
        else
          env.err.print("Something went wrong while building the application")
        end
      else
        env.err.print("Could not load module '" + module_name + "'")
      end
    else
      env.err.print(
        "Please use `--application-module=MODULE_NAME` to specify " +
        "an application module")
    end
