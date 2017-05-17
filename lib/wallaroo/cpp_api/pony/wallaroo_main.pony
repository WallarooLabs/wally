use "wallaroo"
use "wallaroo/topology"

use @w_wrapper_main[Bool](argc: U32, argv: Pointer[Pointer[U8] tag] tag,
  application_builder: CPPApplicationBuilder)

class WallarooMain
  new create(env: Env) =>
    try
      (let argc, let argv) = _extract_c_args(WallarooConfig.application_args(env.args))

      let application = recover
        let application_builder: CPPApplicationBuilder ref = CPPApplicationBuilder
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
