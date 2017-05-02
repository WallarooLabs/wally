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
    env.out.print("out")
    env.out.print(Dianoga.test())
    env.out.print(Dianoga.test_c())
    Dianoga.start_python()
    // env.out.print(Dianoga.test_python())

    try
      let module_name = find_python_module(env.args)
      let module = Dianoga.load_module(module_name)
      let application_setup = Dianoga.application_setup(module, env.args)

      try
        let application = recover val
          let app = Application("")
          Dianoga.apply_application_setup(app, application_setup)
          app
        end
        Startup(env, application, None)
      else
        env.err.print("Something went wrong while building the application")
      end
    else
      env.err.print("could not find wallaroo module")
    end
