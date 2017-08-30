use "collections"
use "buffered"
use "random"

use "sendence/rand"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/messages"
use "wallaroo/ent/w_actor"
use "wallaroo/sink/tcp_sink"
use "wallaroo/source/tcp_source"

use @set_user_serialization_fns[None](module: Pointer[U8] tag)
use @user_serialization_get_size[USize](o: Pointer[U8] tag)
use @user_serialization[None](o: Pointer[U8] tag, bs: Pointer[U8] tag)
use @user_deserialization[Pointer[U8] val](bs: Pointer[U8] tag)

use @load_module[ModuleP](module_name: CString)
use @create_actor_system[Pointer[U8] val](module: ModuleP, args: Pointer[U8] val)
use @list_item_count[USize](list: Pointer[U8] val)
use @get_name[Pointer[U8] val](o: Pointer[U8] val)
use @get_app_name[Pointer[U8] val](o: Pointer[U8] val)
use @get_attribute[Pointer[U8] val](o: Pointer[U8] val, prop: CString)
use @get_string_attribute[Pointer[U8] val](o: Pointer[U8] val, prop: CString)
use @call_str_fn[Pointer[U8] ref](o: Pointer[U8] val, fn: CString,
  args: Pointer[U8] val)
use @call_str_fn_noargs[Pointer[U8] val](o: Pointer[U8] val, fn: CString)
use @call_fn_noargs[Pointer[U8] val](o: Pointer[U8] val, fn: CString)
use @call_fn_u128arg[Pointer[U8] val](o: Pointer[U8] val, fn: CString, id: U128)
use @call_fn_sizet_noargs[USize](o: Pointer[U8] val, fn: CString)
use @call_fn_sizet_bufferarg[USize](o: Pointer[U8] val, fn: CString,
  data: Pointer[U8] tag, size: USize)
use @call_fn_bufferarg[Pointer[U8] val](o: Pointer[U8] val, fn: CString,
  data: Pointer[U8] tag, size: USize)
use @get_actor_count[USize](m: ModuleP)
use @call_fn[Pointer[U8] val](actr: Pointer[U8] val,
  f_name: CString, args: Pointer[U8] tag)
use @call_fn_with_str[Pointer[U8] val](actr: Pointer[U8] val,
  f_name: CString, strArg: CString, args: Pointer[U8] tag)
use @call_fn_with_id[Pointer[U8] val](actr: Pointer[U8] val,
  f_name: CString, sender_id: U128 val, args: Pointer[U8] tag)
use @get_none[Pointer[U8] val]()
use @join_longs[U128](long_pair: Pointer[U8] tag)

use @Py_Initialize[None]()
use @PyTuple_GetItem[Pointer[U8] val](t: Pointer[U8] val, idx: USize)
use @PyString_Size[USize](str: Pointer[U8] box)
use @PyString_AsString[Pointer[U8]](str: Pointer[U8] box)
use @PyString_FromStringAndSize[Pointer[U8]](str: Pointer[U8] tag, size: USize)
use @PyList_New[Pointer[U8] val](size: USize)
use @PyList_Size[USize](l: Pointer[U8] box)
use @PyList_GetItem[Pointer[U8] val](l: Pointer[U8] box, i: USize)
use @PyList_SetItem[I32](l: Pointer[U8] box, i: USize, item: Pointer[U8] box)
use @PyInt_AsLong[I64](i: Pointer[U8] box)
use @PyInt_AsSsize_t[USize](i: Pointer[U8] box)

use @py_incref[None](o: Pointer[U8] box)
use @py_decref[None](o: Pointer[U8] box)

type CString is Pointer[U8] tag

type ModuleP is Pointer[U8] val


class PyData
  var _data: Pointer[U8] val

  new val create(data: Pointer[U8] val) =>
    _data = data

  fun obj(): Pointer[U8] val =>
    _data

  fun _serialise_space(): USize =>
    Atkin.user_serialization_get_size(_data)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Atkin.user_serialization(_data, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _data = recover Atkin.user_deserialization(bytes) end

  fun _final() =>
    @py_decref(_data)


class PySource is WActorFramedSourceHandler
  var _source: Pointer[U8] val

  new val create(source: Pointer[U8] val) =>
    _source = source

  fun header_length(): USize =>
    let length = @call_fn_sizet_noargs(_source, "header_length".cstring())
    if Atkin.print_errors() then
      Fail()
    end
    length

  fun payload_length(data: Array[U8] iso): USize =>
    let length = @call_fn_sizet_bufferarg(_source,
      "payload_length".cstring(), data.cpointer(), data.size())
    if Atkin.print_errors() then
      Fail()
    end
    length

  fun decode(data: Array[U8] val): PyData val ? =>
    let decoded = @call_fn_bufferarg(_source, "decode".cstring(),
      data.cpointer(), data.size())
    if Atkin.print_errors() then
      error
    end
    @py_incref(decoded)
    PyData(decoded)

  fun _serialise_space(): USize =>
    Atkin.user_serialization_get_size(_source)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Atkin.user_serialization(_source, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _source = recover Atkin.user_deserialization(bytes) end

  fun _final() =>
    @py_decref(_source)


class PySink
  var _sink: Pointer[U8] val

  new val create(sink: Pointer[U8] val) =>
    _sink = sink

  fun apply(f: (PyData val | None), wb: Writer): Array[ByteSeq] val =>
    match f
    | let p: PyData val =>
      let arr = recover val
        let data = @call_fn(_sink, "encode".cstring(), p.obj())
        if Atkin.print_errors() then
          Fail()
        end
        Array[U8].from_cpointer(@PyString_AsString(data), @PyString_Size(data)).clone()
      end
      wb.write(arr)
    end
    wb.done()

  fun _serialise_space(): USize =>
    Atkin.user_serialization_get_size(_sink)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Atkin.user_serialization(_sink, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _sink = recover Atkin.user_deserialization(bytes) end

  fun _final() =>
    @py_decref(_sink)


class PyActorBuilder
  var _pyactor: Pointer[U8] val

  new val create(pyactor: Pointer[U8] val) =>
    _pyactor = pyactor

  fun apply(id: U128, wh: WActorHelper): WActor =>
    PyActor(_pyactor, wh, id)

  fun _serialise_space(): USize =>
    Atkin.user_serialization_get_size(_pyactor)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Atkin.user_serialization(_pyactor, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _pyactor = recover Atkin.user_deserialization(bytes) end

  fun _final() =>
    @py_decref(_pyactor)

class PyActor is WActor
  var _actor: Pointer[U8] val
  let _id: U128

  new create(actr: Pointer[U8] val, h: WActorHelper, id': U128) =>
    _actor = actr
    _id = id'
    let helper_calls = @call_fn_u128arg(_actor, "setup_wrapper".cstring(), id')
    if Atkin.print_errors() then
      Fail()
    end
    run_helper_calls(h, helper_calls)

  fun ref run_helper_calls(helper: WActorHelper, helper_calls: Pointer[U8] val) =>
    let call_count = @list_item_count(helper_calls)
    for idx in Range(0, call_count) do
      let call = @PyList_GetItem(helper_calls, idx)
      if not call.is_null() then
        let call_name = recover val
          let s = @PyTuple_GetItem(call, 0)
          let r = String.copy_cstring(@PyString_AsString(s))
          r
        end
        let call_args = @PyTuple_GetItem(call, 1)
        match call_name
        | "send_to" =>
          let long_pair = @PyTuple_GetItem(call_args, 0)
          let actor_id = @join_longs(long_pair)
          let msg = @PyTuple_GetItem(call_args, 1)
          helper.send_to(actor_id, Atkin.wrap_pointer(msg))
        | "send_to_role" =>
          let role = recover val
            let s = @PyTuple_GetItem(call_args, 0)
            String.copy_cstring(@PyString_AsString(s))
          end
          let msg = @PyTuple_GetItem(call_args, 1)
          helper.send_to_role(role, Atkin.wrap_pointer(msg))
        //| "create_actor" =>
        //| "destroy_actor" =>
        //| "set_timer" =>
        //| "cancel_timer" =>
        | "send_to_sink" =>
          let s = @PyTuple_GetItem(call_args, 0)
          let sink = @PyInt_AsSsize_t(s)
          let msg = @PyTuple_GetItem(call_args, 1)
          helper.send_to_sink[(PyData val | None)](sink, Atkin.wrap_pointer(msg))
        | "register_as_role" =>
          let role = recover val
            let s = @PyTuple_GetItem(call, 1)
            String.copy_cstring(@PyString_AsString(s))
          end
          helper.register_as_role(role)
        | "subscribe_to_broadcast_variable" =>
          let var_name = recover val
            let s = @PyTuple_GetItem(call, 1)
            String.copy_cstring(@PyString_AsString(s))
          end
          helper.subscribe_to_broadcast_variable(var_name)
        | "update_broadcast_variable" =>
          let var_name = recover val
            let s = @PyTuple_GetItem(call_args, 0)
            String.copy_cstring(@PyString_AsString(s))
          end
          let new_value = @PyTuple_GetItem(call_args, 1)
          helper.update_broadcast_variable(var_name,
                                           Atkin.wrap_pointer(new_value))
        else
          Fail()
        end
      end
    end
    @py_decref(helper_calls)

  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    match payload
    | let p: PyData val =>
      let helper_calls = @call_fn_with_id(_actor, "receive_wrapper".cstring(),
                                          sender, p.obj())
      if Atkin.print_errors() then
        Fail()
      end
      run_helper_calls(h, helper_calls)
    else
      Fail()
    end

  fun ref process(data: Any val, h: WActorHelper) =>
    match data
    | let d: PyData val =>
      let helper_calls = @call_fn(_actor, "process_wrapper".cstring(), d.obj())
      if Atkin.print_errors() then
        Fail()
      end
      run_helper_calls(h, helper_calls)
    | Act =>
      let helper_calls = @call_fn_noargs(_actor, "process_wrapper".cstring())
      if Atkin.print_errors() then
        Fail()
      end
      run_helper_calls(h, helper_calls)
    else
      Fail()
    end

  fun ref receive_broadcast_variable_update(var_name: String, payload: Any val) =>
    match payload
    | let p: PyData val =>
      @call_fn_with_str(_actor,
                        "receive_broadcast_variable_update_wrapper".cstring(),
                        var_name.cstring(),
                        p.obj())
      if Atkin.print_errors() then
        Fail()
      end
    else
      Fail()
    end

  fun _serialise_space(): USize =>
    Atkin.user_serialization_get_size(_actor)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Atkin.user_serialization(_actor, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _actor = recover Atkin.user_deserialization(bytes) end

  fun _final() =>
    @py_decref(_actor)


primitive Atkin

  fun print_errors(): Bool =>
    let er = @PyErr_Occurred[Pointer[U8]]()
    if not er.is_null() then
      @PyErr_Print[None]()
      true
    else
      false
    end

  fun load_module(module_name: String): ModuleP ? =>
    let r = @load_module(module_name.cstring())
    if print_errors() then
      error
    end
    r

  fun wrap_pointer(r: Pointer[U8] val): (PyData val | None val) =>
    if not r.is_null() then
      @py_incref(r)
      PyData(r)
    else
      None
    end

  fun start_python() =>
    @Py_Initialize()

  fun pony_array_string_to_py_list_string(args: Array[String] val):
    Pointer[U8] val
  =>
    let l = @PyList_New(args.size())
    for (i, v) in args.pairs() do
      @PyList_SetItem(l, i, @PyString_FromStringAndSize(v.cstring(), v.size()))
    end
    l

  fun set_user_serialization_fns(m: Pointer[U8] val) =>
    @set_user_serialization_fns(m)

  fun user_serialization_get_size(o: Pointer[U8] tag): USize =>
    let r = @user_serialization_get_size(o)
    if (print_errors()) then
      @printf[U32]("Serialization failed".cstring())
    end
    r

  fun user_serialization(o: Pointer[U8] tag, bs: Pointer[U8] tag) =>
    @user_serialization(o, bs)
    if (print_errors()) then
      @printf[U32]("Serialization failed".cstring())
    end

  fun user_deserialization(bs: Pointer[U8] tag): Pointer[U8] val =>
    let r = @user_deserialization(bs)
    if (print_errors()) then
      @printf[U32]("Deserialization failed".cstring())
    end
    r

  fun create_actor_system(module: ModuleP, args: Array[String] val,
    tcp_sink_configs: Array[TCPSinkConfigOptions] val,
    init_seed: U64): ActorSystem val ?
  =>
    let pyargs = pony_array_string_to_py_list_string(args)
    let pyactor_system = @create_actor_system(module, pyargs)
    if print_errors() then
      error
    end
    let actor_system = recover iso ActorSystem(
      recover val String.copy_cstring(@get_name(pyactor_system)) end,
      init_seed) end
    let pysource_list = @get_attribute(pyactor_system, "sources".cstring())
    if not pysource_list.is_null() then
      let pysource_list_count = @list_item_count(pysource_list)
      for idx in Range(0, pysource_list_count) do
        let pysource = @PyList_GetItem(pysource_list, idx)
        @py_incref(pysource)
        let pysource_kind = String.copy_cstring(
          @call_str_fn_noargs(pysource, "kind".cstring()))
        if pysource_kind == "simulated" then
          actor_system.add_source(SimulationFramedSourceHandler, IngressWActorRouter)
        else
          let source = PySource(pysource)
          actor_system.add_source(source, IngressWActorRouter)
        end
      end
      @py_decref(pysource_list)
    end
    let pysink_list = @get_attribute(pyactor_system, "sinks".cstring())
    if not pysink_list.is_null() then
      let pysink_list_count = @list_item_count(pysink_list)
      for idx in Range(0, pysink_list_count) do
        let pysink = @PyList_GetItem(pysink_list, idx)
        @py_incref(pysink)
        let sink = PySink(pysink)
        actor_system.add_sink[(PyData val | None)](
          TCPSinkConfig[PyData val].from_options(sink, tcp_sink_configs(idx)))
      end
      @py_decref(pysink_list)
    end
    let pyactor_list = @get_attribute(pyactor_system, "actors".cstring())
    if not pyactor_list.is_null() then
      let pyactor_list_count = @list_item_count(pyactor_list)
      for idx in Range(0, pyactor_list_count) do
        let pyactor = @PyList_GetItem(pyactor_list, idx)
        @py_incref(pyactor)
        let actor_builder = PyActorBuilder(pyactor)
        actor_system.add_actor(actor_builder)
      end
      @py_decref(pyactor_list)
    end
    let pybvar_list = @get_attribute(pyactor_system, "broadcast_variables".cstring())
    if not pybvar_list.is_null() then
      let pybvar_list_count = @list_item_count(pybvar_list)
      for idx in Range(0, pybvar_list_count) do
        let pybvar = @PyList_GetItem(pybvar_list, idx)
        let key = recover val
          let s = @PyTuple_GetItem(pybvar, 0)
          let r = String.copy_cstring(@PyString_AsString(s))
          r
        end
        let default_value = Atkin.wrap_pointer(@PyTuple_GetItem(pybvar, 1))
        actor_system.create_broadcast_variable(key, default_value)
      end
      @py_decref(pybvar_list)
    end
    actor_system

  fun startup(env: Env, module: ModuleP, actor_system: ActorSystem val) =>
    ActorSystemStartup(env, actor_system, actor_system.name())
