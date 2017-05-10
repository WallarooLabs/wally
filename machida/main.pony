use "collections"
use "options"

use "wallaroo"
use "wallaroo/tcp_source"
use "wallaroo/topology"

use "lib:python2.7"
use "lib:python-wallaroo"

actor Main
  fun find_python_module(args: Array[String] val): String ? =>
    let options = Options(args, false)
    options.add("application-module", "", StringArgument)

    var module_name: (None | String) = None

    for option in options do
      match option
      | ("application-module", let arg: String) => module_name = arg
      end
    end

    module_name as String

  new create(env: Env) =>
    Machida.start_python()

    try
      let module_name = find_python_module(env.args)

      try
        let module = Machida.load_module(module_name)

        try
          let application_setup = Machida.application_setup(module, env.args)
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
        "Please use `--application-module=MODULE_NAME` to specify an application module")
    end
