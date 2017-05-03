use "collections"
use "debug"

use "wallaroo"
use "wallaroo/tcp_source"
use "wallaroo/topology"

use "lib:python2.7"
use "lib:python-wallaroo"

actor Main
  fun find_python_module(args: Array[String] val): String ? =>
    var i: USize = 0
    while i < args.size() do
      if "--wallaroo-module" == args(i) then
        return args(i + 1)
      end
      i = i + 1
    end
    error

  new create(env: Env) =>
    Machida.start_python()

    try
      let module_name = find_python_module(env.args)
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
      env.err.print("could not find wallaroo module")
    end
