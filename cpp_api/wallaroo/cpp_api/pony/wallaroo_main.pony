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

use "wallaroo"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

use @w_wrapper_main[Bool](argc: U32, argv: Pointer[Pointer[U8] tag] tag,
  application_builder: CPPApplicationBuilder)

class WallarooMain
  new create(env: Env) =>
    try
      (let argc, let argv) = _extract_c_args(WallarooConfig.application_args(env.args))

      let application = recover
        let source_configs = TCPSourceConfigCLIParser(env.args)
        let sink_configs = TCPSinkConfigCLIParser(env.args)
        let application_builder: CPPApplicationBuilder ref =
          CPPApplicationBuilder(source_configs, sink_configs)
        let res = @w_wrapper_main(argc, argv, application_builder)
        if not res then
          error
        end
        application_builder.build()
      end

      Startup(env, consume application, None)
    else
      @printf[I32]("Could not build application\n".cstring())
    end

  fun _extract_c_args(pony_args: Array[String] val): (U32, Pointer[Pointer[U8] tag] tag) =>
    let argc = pony_args.size().u32()
    let pony_argv = recover iso Array[Pointer[U8] tag] end

    for arg in pony_args.values() do
      pony_argv.push(arg.cpointer())
    end

    (argc, pony_argv.cpointer())
