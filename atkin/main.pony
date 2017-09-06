/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"

use "wallaroo_labs/options"
use "wallaroo"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/topology"

use "lib:python2.7"
use "lib:python-wactor"

actor Main
  new create(env: Env) =>
    let seed: U64 = 12345

    Atkin.start_python()

    try
      var module_name: String = ""

      let options = Options(WallarooConfig.application_args(env.args), false)
      options.add("application-module", "", StringArgument)

      for option in options do
        match option
        | ("application-module", let arg: String) => module_name = arg
        end
      end

      try
        let module = Atkin.load_module(module_name)

        try
          let tcp_sink_configs = TCPSinkConfigCLIParser(env.args)

          Atkin.set_user_serialization_fns(module)
          let actor_system = Atkin.create_actor_system(module,
            options.remaining(), tcp_sink_configs, seed)
          Atkin.startup(env, module, actor_system)
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
