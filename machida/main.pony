/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "collections"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"
use "wallaroo_labs/options"
use "wallaroo_labs/thread_count"
use "wallaroo"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

use "lib:python2.7"
use "lib:python-wallaroo"

actor Main
  new create(env: Env) =>
    Log.set_defaults()

    let pony_thread_count = ThreadCount()

    if pony_thread_count != 1 then
      FatalUserError("You must provide Machida with the '--ponythreads 1' argument to ensure it is single-threaded for the Python API or the cluster will crash.\n")
    end

    Machida.start_python()

    try
      var module_name: String = ""

      let options = Options(WallarooConfig.application_args(env.args)?, false)
      options.add("application-module", "", StringArgument)
      options.add("help", "h", None)

      for option in options do
        match option
        | ("help", let arg: None) =>
          MachidaStartupHelp()
          return
        | ("application-module", let arg: String) => module_name = arg
        end
      end

      if module_name == "" then
        FatalUserError("You must provide Machida with --application-module\n")
      end

      try
        let module = Machida.load_module(module_name)?

        try
          Machida.set_user_serialization_fns(module)
          Machida.set_command_line_args(module, env.args)

          let application_setup =
            Machida.application_setup(module, options.remaining())?
          (let app_name, let pipeline) = recover val
            Machida.apply_application_setup(application_setup, env)?
          end
          Wallaroo.build_application(env, app_name, pipeline)
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
