use "collections"
use "buffered"
use "debug"

use "wallaroo"
use "wallaroo/tcp_source"
use "wallaroo/topology"
use "wallaroo/messages"

use @test_c[Pointer[U8] val]()
use @test_python[Pointer[U8] val]()

use @load_module[ModuleP](module_name: CString)

use @application_setup[Pointer[U8] val](module: ModuleP, args: Pointer[U8] val)

use @list_item_count[USize](list: Pointer[U8] val)

use @instantiate_python_class[Pointer[U8] val](klass: Pointer[U8] val)

use @get_application_setup_item[Pointer[U8] val](list: Pointer[U8] val, idx: USize)
use @get_application_setup_action[Pointer[U8] val](item: Pointer[U8] val)
// use @get_application_setup_args[Pointer[U8] val](item: Pointer[U8] val)

use @get_name[Pointer[U8] val](o: Pointer[U8] val)
use @computation_compute[Pointer[U8] val](c: Pointer[U8] val, d: Pointer[U8] val)

use @state_builder_build_state[Pointer[U8] val](sb: Pointer[U8] val)
use @stateful_computation_compute[Pointer[U8] val](c: Pointer[U8] val, d: Pointer[U8] val, s: Pointer[U8] val)

use @source_decoder_header_length[USize](source_decoder: Pointer[U8] val)
use @source_decoder_payload_length[USize](source_decoder: Pointer[U8] val, data: Pointer[U8] tag, size: USize)
use @source_decoder_decode[Pointer[U8] val](source_decoder: Pointer[U8] val, data: Pointer[U8] tag, size: USize)

use @sink_encoder_encode[Pointer[U8] val](sink_encoder: Pointer[U8] val, data: Pointer[U8] val)

use @partition_function_partition_u64[U64](partition_function: Pointer[U8] val, data: Pointer[U8] val)

use @partition_function_partition[Pointer[U8] val](partition_function: Pointer[U8] val, data: Pointer[U8] val)

use @key_hash[U64](key: Pointer[U8] val)
use @key_eq[I32](key: Pointer[U8] val, other: Pointer[U8] val)

use @py_incref[None](o: Pointer[U8] box)
use @py_decref[None](o: Pointer[U8] box)

use @Py_Initialize[None]()
use @PyTuple_GetItem[Pointer[U8] val](t: Pointer[U8] val, idx: USize)
use @PyByteArray_AsString[Pointer[U8]](ba: Pointer[U8] box)
use @PyByteArray_Size[USize](ba: Pointer[U8] box)
use @PyString_AsString[Pointer[U8]](ba: Pointer[U8] box)
use @PyString_FromStringAndSize[Pointer[U8]](str: Pointer[U8] tag, size: USize)
use @PyList_New[Pointer[U8] val](size: USize)
use @PyList_Size[USize](l: Pointer[U8] box)
use @PyList_GetItem[Pointer[U8] val](l: Pointer[U8] box, i: USize)
use @PyList_SetItem[I32](l: Pointer[U8] box, i: USize, item: Pointer[U8] box)
use @PyInt_AsLong[I64](i: Pointer[U8] box)

type CString is Pointer[U8] tag

type ModuleP is Pointer[U8] val

class PyData
  var _data: Pointer[U8] val

  new create(data: Pointer[U8] val) =>
    _data = data

  fun obj(): Pointer[U8] val =>
    _data

  fun _final() =>
    Dianoga.dec_ref(_data)

class PyState
  var _state: Pointer[U8] val

  new create(state: Pointer[U8] val) =>
    _state = state

  fun obj(): Pointer[U8] val =>
    _state

  fun _final() =>
    Dianoga.dec_ref(_state)

class PyStateBuilder
  var _state_builder: Pointer[U8] val

  new create(state_builder: Pointer[U8] val) =>
    _state_builder = state_builder

  fun name(): String =>
    Dianoga.get_name(_state_builder)

  fun apply(): PyState =>
    PyState(@state_builder_build_state(_state_builder))

  fun _final() =>
    Dianoga.dec_ref(_state_builder)

class PyPartitionFunctionU64
  var _partition_function: Pointer[U8] val

  new create(partition_function: Pointer[U8] val) =>
    _partition_function = partition_function

  fun apply(data: PyData val): U64 =>
    Dianoga.partition_function_partition_u64(_partition_function, data.obj())

  fun _final() =>
    Dianoga.dec_ref(_partition_function)

class PyKey is (Hashable & Equatable[PyKey])
  var _key: Pointer[U8] val

  new create(key: Pointer[U8] val) =>
    _key = key

  fun obj(): Pointer[U8] val =>
    _key

  fun hash(): U64 =>
    Dianoga.key_hash(obj())

  fun eq(other: PyKey box): Bool =>
    Dianoga.key_eq(obj(), other.obj())

  fun _final() =>
    Dianoga.dec_ref(_key)

class PyPartitionFunction
  var _partition_function: Pointer[U8] val

  new create(partition_function: Pointer[U8] val) =>
    _partition_function = partition_function

  fun apply(data: PyData val): PyKey val =>
    recover
      PyKey(Dianoga.partition_function_partition(_partition_function, data.obj()))
    end

  fun _final() =>
    Dianoga.dec_ref(_partition_function)

class PyFramedSourceHandler is FramedSourceHandler[PyData val]
  var _source_decoder: Pointer[U8] val
  let _header_length: USize

  new create(source_decoder: Pointer[U8] val) =>
    _source_decoder = source_decoder
    _header_length = Dianoga.source_decoder_header_length(_source_decoder)

  fun header_length(): USize =>
    _header_length

  fun payload_length(data: Array[U8] iso): USize =>
    Dianoga.source_decoder_payload_length(_source_decoder, data.cpointer(), data.size())

  fun decode(data: Array[U8] val): PyData val =>
    recover
      PyData(Dianoga.source_decoder_decode(_source_decoder, data.cpointer(), data.size()))
    end

  fun _final() =>
    Dianoga.dec_ref(_source_decoder)

class PyComputation is Computation[PyData val, PyData val]
  var _computation: Pointer[U8] val
  let _name: String

  new create(computation: Pointer[U8] val) =>
    _computation = computation
    _name = Dianoga.get_name(_computation)

  fun apply(input: PyData val): (PyData val | None) =>
    let r: Pointer[U8] val = Dianoga.computation_compute(_computation, input.obj())

    if not r.is_null() then
      recover
        PyData(r)
      end
    else
      None
    end

  fun name(): String =>
    _name

  fun _final() =>
    Dianoga.dec_ref(_computation)

class PyStateComputation is StateComputation[PyData val, PyData val, PyState]
  var _computation: Pointer[U8] val
  let _name: String

  new create(computation: Pointer[U8] val) =>
    _computation = computation
    _name = Dianoga.get_name(_computation)

  fun apply(input: PyData val,
    sc_repo: StateChangeRepository[PyState], state: PyState):
    ((PyData val | None), None)
  =>
    let data = Dianoga.stateful_computation_compute(_computation, input.obj(), state.obj())
    let d = recover if data.is_null() then
        None
      else
        recover val PyData(data) end
      end
    end
    (d, None)

  fun name(): String =>
    _name

  fun state_change_builders(): Array[StateChangeBuilder[PyState] val] val =>
    recover val Array[StateChangeBuilder[PyState] val] end

  fun _final() =>
    Dianoga.dec_ref(_computation)

class PyEncoder is SinkEncoder[PyData val]
  var _sink_encoder: Pointer[U8] val

  new create(sink_encoder: Pointer[U8] val) =>
    _sink_encoder = sink_encoder

  fun apply(data: PyData val, wb: Writer): Array[ByteSeq] val =>
    let byte_buffer = Dianoga.sink_encoder_encode(_sink_encoder, data.obj())
    let arr = recover val
      // create a temporary Array[U8] wrapper for the C array, then clone it
      Array[U8].from_cpointer(@PyByteArray_AsString(byte_buffer), @PyByteArray_Size(byte_buffer)).clone()
    end
    Dianoga.dec_ref(byte_buffer)
    wb.write(arr)
    wb.done()

  fun _final() =>
    Dianoga.dec_ref(_sink_encoder)

primitive Dianoga
  fun print_errors() =>
    let er = @PyErr_Occurred[Pointer[U8]]()
    if not er.is_null() then
      @PyErr_Print[None]()
    end

  fun test(): String =>
    "hello from dianoga"

  fun test_c(): String =>
    recover
      String.copy_cstring(@test_c())
    end

  fun start_python() =>
    @Py_Initialize()

  fun test_python(): String =>
    recover
      String.copy_cstring(@test_python())
    end

  fun load_module(module_name: String): ModuleP =>
    let r = @load_module(module_name.cstring())
    print_errors()
    r

  fun application_setup(module: ModuleP, args: Array[String] val): Pointer[U8] val =>
    let pyargs = Dianoga.pony_array_string_to_py_list_string(args)
    let r = @application_setup(module, pyargs)
    print_errors()
    r

  fun apply_application_setup(app: Application,
    application_setup_data: Pointer[U8] val)
  ? =>
    let application_setup_item_count = @list_item_count(application_setup_data)
    var latest: (Application | PipelineBuilder[PyData val, PyData val, PyData val]) = app
    for idx in Range(0, application_setup_item_count) do
      let item = @get_application_setup_item(application_setup_data, idx)
      let action_p = @get_application_setup_action(item)
      let action = String.copy_cstring(action_p)
      Debug("action = '" +  action + "'")
      match action
      | "new_pipeline" =>
        Debug("  adding new pipeline")
        let name = recover val
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(item, 1)))
        end
        let decoder = recover val
          let d = @PyTuple_GetItem(item, 2)
          Dianoga.inc_ref(d)
          PyFramedSourceHandler(d)
        end
        Debug("!!! decoder header_length = " + decoder.header_length().string())
        latest = (latest as Application).new_pipeline[PyData val, PyData val](name, decoder)
      | "to" =>
        Debug("  adding a computation to the pipeline")
        let computation_class = @PyTuple_GetItem(item, 1)
        Dianoga.inc_ref(computation_class)
        let builder = recover val
          {()(computation_class): PyComputation iso^ =>
            recover
              PyComputation(@instantiate_python_class(computation_class))
            end
          }
        end
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to[PyData val](builder)
      | "to_stateful" =>
        Debug("  adding a state computation to the pipeline")
        let state_computationp = @PyTuple_GetItem(item, 1)
        Dianoga.inc_ref(state_computationp)
        let state_computation = recover val
          PyStateComputation(state_computationp)
        end

        let state_builderp = @PyTuple_GetItem(item, 2)
        Dianoga.inc_ref(state_builderp)
        let state_builder = recover val
          PyStateBuilder(state_builderp)
        end

        let state_name = recover val
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(item, 3)))
        end
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to_stateful[PyData val, PyState](state_computation, state_builder, state_name)
      | "to_state_partition_u64" =>
        Debug("  adding a u64 partitioned state computation to the pipeline")
        let state_computationp = @PyTuple_GetItem(item, 1)
        Dianoga.inc_ref(state_computationp)
        let state_computation = recover val
          PyStateComputation(state_computationp)
        end

        let state_builderp = @PyTuple_GetItem(item, 2)
        Dianoga.inc_ref(state_builderp)
        let state_builder = recover val
          PyStateBuilder(state_builderp)
        end

        let state_name = recover val
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(item, 3)))
        end

        let partition_functionp = @PyTuple_GetItem(item, 4)
        Dianoga.inc_ref(partition_functionp)
        let partition_function = recover val
          PyPartitionFunctionU64(partition_functionp)
        end

        let partition_values = Dianoga.py_list_int_to_pony_array_u64(@PyTuple_GetItem(item, 5))

        let partition = Partition[PyData val, U64](partition_function, partition_values)
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to_state_partition[PyData val, U64, PyData val, PyState](state_computation, state_builder, state_name, partition)
      | "to_state_partition" =>
        Debug("  adding a partitioned state computation to the pipeline")
        let state_computationp = @PyTuple_GetItem(item, 1)
        Dianoga.inc_ref(state_computationp)
        let state_computation = recover val
          PyStateComputation(state_computationp)
        end

        let state_builderp = @PyTuple_GetItem(item, 2)
        Dianoga.inc_ref(state_builderp)
        let state_builder = recover val
          PyStateBuilder(state_builderp)
        end

        let state_name = recover val
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(item, 3)))
        end

        let partition_functionp = @PyTuple_GetItem(item, 4)
        Dianoga.inc_ref(partition_functionp)
        let partition_function = recover val
          PyPartitionFunction(partition_functionp)
        end

        let partition_values = Dianoga.py_list_int_to_pony_array_pykey(@PyTuple_GetItem(item, 5))

        let partition = Partition[PyData val, PyKey val](partition_function, partition_values)
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to_state_partition[PyData val, PyKey val, PyData val, PyState](state_computation, state_builder, state_name, partition)
      | "to_sink" =>
        Debug("  adding a sink to the pipeline")
        let encoderp = @PyTuple_GetItem(item, 1)
        Dianoga.inc_ref(encoderp)
        let encoder = recover val
          PyEncoder(encoderp)
        end
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to_sink(encoder, recover [0] end)
        latest
      | "done" =>
        Debug("  adding a null sink to the pipeline")
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.done()
        latest
      end
    end

    Dianoga.dec_ref(application_setup_data)

  fun source_decoder_header_length(source_decoder: Pointer[U8] val): USize =>
    let r = @source_decoder_header_length(source_decoder)
    print_errors()
    r

  fun source_decoder_payload_length(source_decoder: Pointer[U8] val, data: Pointer[U8] tag, size: USize): USize =>
    let r = @source_decoder_payload_length(source_decoder, data, size)
    print_errors()
    r

  fun source_decoder_decode(source_decoder: Pointer[U8] val, data: Pointer[U8] tag, size: USize): Pointer[U8] val =>
    let r = @source_decoder_decode(source_decoder, data, size)
    print_errors()
    r

  fun sink_encoder_encode(sink_encoder: Pointer[U8] val, data: Pointer[U8] val): Pointer[U8] val =>
    let r = @sink_encoder_encode(sink_encoder, data)
    print_errors()
    r

  fun computation_compute(computation: Pointer[U8] val, data: Pointer[U8] val): Pointer[U8] val =>
    let r = @computation_compute(computation, data)
    print_errors()
    r

  fun stateful_computation_compute(computation: Pointer[U8] val, data: Pointer[U8] val, state: Pointer[U8] val): Pointer[U8] val =>
    let r = @stateful_computation_compute(computation, data, state)
    print_errors()
    r

  fun partition_function_partition_u64(partition_function: Pointer[U8] val, data: Pointer[U8] val): U64 =>
    let r = @partition_function_partition_u64(partition_function, data)
    print_errors()
    r

  fun py_list_int_to_pony_array_u64(py_array: Pointer[U8] val): Array[U64] val =>
    let size = @PyList_Size(py_array)
    let arr = recover iso Array[U64](size) end

    for i in Range(0, size) do
      let obj = @PyList_GetItem(py_array, i)
      let v = @PyInt_AsLong(obj)
      arr.push(v.u64())
    end

    consume arr

  fun key_hash(key: Pointer[U8] val): U64 =>
    let r = @key_hash(key)
    print_errors()
    r

  fun key_eq(key: Pointer[U8] val, other: Pointer[U8] val): Bool =>
    let r = not (@key_eq(key, other) == 0)
    print_errors()
    r

  fun partition_function_partition(partition_function: Pointer[U8] val, data: Pointer[U8] val): Pointer[U8] val =>
    let r = @partition_function_partition(partition_function, data)
    print_errors()
    r

  fun py_list_int_to_pony_array_pykey(py_array: Pointer[U8] val): Array[PyKey val] val =>
    let size = @PyList_Size(py_array)
    let arr = recover iso Array[PyKey val](size) end

    for i in Range(0, size) do
      let obj = @PyList_GetItem(py_array, i)
      Dianoga.inc_ref(obj)
      arr.push(recover val PyKey(obj) end)
    end

    consume arr

  fun pony_array_string_to_py_list_string(args: Array[String] val): Pointer[U8] val =>
    let l = @PyList_New(args.size())
    for (i, v) in args.pairs() do
      @PyList_SetItem(l, i, @PyString_FromStringAndSize(v.cstring(), v.size()))
    end
    l

  fun get_name(o: Pointer[U8] val): String =>
    let ps = @get_name(o)
    let s = recover
      String.copy_cstring(@PyString_AsString(ps))
    end
    dec_ref(ps)
    s

  fun inc_ref(o: Pointer[U8] box) =>
    @py_incref(o)

  fun dec_ref(o: Pointer[U8] box) =>
    @py_decref(o)
