use "collections"

use "lib:python2.7"
use "lib:mypython"

use @initialize_python[None]()

use @test[None]()
use @test_python[None]()

use @get_python_module[Pointer[U8] val](name: Pointer[U8] tag)
use @call_python_function[Pointer[U8] val](module: Pointer[U8] val, function_name: Pointer[U8] tag)

use @call_python_function_with_arg[Pointer[U8] val](module: Pointer[U8] val, function_name: Pointer[U8] tag, arg: Pointer[U8] val)

use @get_item_count[USize](a: Pointer[U8] val)
use @get_action_at[Pointer[U8] val](a: Pointer[U8] val, idx: USize)

actor Main
  fun initialize_python() =>
    @initialize_python()

  fun call_c() =>
    @test()

  fun call_c_python() =>
    @test_python()

  fun get_python_module(): Pointer[U8] val =>
    @get_python_module("mypy".cstring())

  fun call_python_function(module: Pointer[U8] val, f_name: String): Pointer[U8] val =>
    @call_python_function(module, f_name.cstring())

  fun call_python_function_with_arg(module: Pointer[U8] val, f_name: String, arg: Pointer[U8] val): Pointer[U8] val =>
    @call_python_function_with_arg(module, f_name.cstring(), arg)

  fun display_application(module: Pointer[U8] val, a: Pointer[U8] val, env: Env) =>
    let application_item_count = @get_item_count(a)
    env.out.print("there are " + application_item_count.string() + " application items")
    for i in Range(0, application_item_count) do
      let action_c_string = @get_action_at(a, i)
      let action_string = String.copy_cstring(action_c_string)
      env.out.print("  action: " + action_string)
    end

  new create(env: Env) =>
    initialize_python()
    env.out.print("hello")
    call_c()
    call_c_python()
    let m = get_python_module()
    call_python_function(m, "f")
    let o = call_python_function(m, "get_obj")
    let i = call_python_function_with_arg(m, "use_obj", o)
    let a = call_python_function(m, "get_application")
    display_application(m, a, env)
