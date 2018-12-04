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
use "buffered"
use "pony-kafka"
use "net"

use "wallaroo"
use "wallaroo/core/common"
use "wallaroo/core/aggregations"
use "wallaroo/core/partitioning"
use "wallaroo/core/sink"
use "wallaroo/core/sink/connector_sink"
use "wallaroo/core/sink/kafka_sink"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/connector_source"
use "wallaroo/core/source/kafka_source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"
use "wallaroo/core/state"
use "wallaroo/core/windows"

// these are included because of wallaroo issue #814
use "serialise"
use "wallaroo_labs/mort"

use @set_user_serialization_fns[None](module: Pointer[U8] tag)
use @user_serialization_get_size[USize](o: Pointer[U8] tag)
use @user_serialization[None](o: Pointer[U8] tag, bs: Pointer[U8] tag)
use @user_deserialization[Pointer[U8] val](bs: Pointer[U8] tag)

use @load_module[ModuleP](module_name: CString)

use @application_setup[Pointer[U8] val](module: ModuleP, args: Pointer[U8] val)

use @list_item_count[USize](list: Pointer[U8] val)

use @instantiate_python_class[Pointer[U8] val](klass: Pointer[U8] val)

use @get_application_setup_item[Pointer[U8] val](list: Pointer[U8] val,
  idx: USize)
use @get_application_setup_action[Pointer[U8] val](item: Pointer[U8] val)


use @get_list_item[Pointer[U8] val](list: Pointer[U8] val, idx: USize)
use @get_stage_command[Pointer[U8] val](item: Pointer[U8] val)


use @get_name[Pointer[U8] val](o: Pointer[U8] val)

use @computation_compute[Pointer[U8] val](c: Pointer[U8] val,
  d: Pointer[U8] val, method: Pointer[U8] tag)

use @stateful_computation_compute[Pointer[U8] val](c: Pointer[U8] val,
  d: Pointer[U8] val, s: Pointer[U8] val, m: Pointer[U8] tag)
use @initial_state[Pointer[U8] val](computation: Pointer[U8] val)

use @initial_accumulator[Pointer[U8] val](aggregation: Pointer[U8] val)
use @aggregation_update[None](aggregation: Pointer[U8] val,
  data: Pointer[U8] val, acc: Pointer[U8] val)
use @aggregation_combine[Pointer[U8] val](aggregation: Pointer[U8] val,
  acc1: Pointer[U8] val, acc2: Pointer[U8] val)
use @aggregation_output[Pointer[U8] val](aggregation: Pointer[U8] val,
  key: Pointer[U8] tag, acc: Pointer[U8] val)

use @source_decoder_header_length[USize](source_decoder: Pointer[U8] val)
use @source_decoder_payload_length[USize](source_decoder: Pointer[U8] val,
  data: Pointer[U8] tag, size: USize)
use @source_decoder_decode[Pointer[U8] val](source_decoder: Pointer[U8] val,
  data: Pointer[U8] tag, size: USize)
use @source_generator_initial_value[Pointer[U8] val](
  source_generator: Pointer[U8] val)
use @source_generator_apply[Pointer[U8] val](source_generator: Pointer[U8] val,
  data: Pointer[U8] tag)

use @sink_encoder_encode[Pointer[U8] val](sink_encoder: Pointer[U8] val,
  data: Pointer[U8] val)

use @extract_key[Pointer[U8] val](key_extractor: Pointer[U8] val,
  data: Pointer[U8] val)

use @key_hash[USize](key: Pointer[U8] val)
use @key_eq[I32](key: Pointer[U8] val, other: Pointer[U8] val)

use @py_bool_check[I32](b: Pointer[U8] box)
use @is_py_none[I32](o: Pointer[U8] box)
use @py_incref[None](o: Pointer[U8] box)
use @py_decref[None](o: Pointer[U8] box)
use @py_list_check[I32](b: Pointer[U8] box)
use @py_tuple_check[I32](p: Pointer[U8] box)
use @py_bytes_check[I32](b: Pointer[U8] tag)
use @py_bytes_or_unicode_size[USize](str: Pointer[U8] tag)
use @py_bytes_or_unicode_as_char[Pointer[U8]](str: Pointer[U8] tag)

use @Py_Initialize[None]()
use @PyErr_Clear[None]()
use @PyErr_Occurred[Pointer[U8]]()
use @PyErr_print[None]()
use @PyTuple_GetItem[Pointer[U8] val](t: Pointer[U8] val, idx: USize)
use @PyBytes_AsStringAndSize[I32](str: Pointer[U8] tag, out: Pointer[Pointer[U8]], size: Pointer[ISize] box)
use @PyBytes_Size[USize](str: Pointer[U8] box)
use @PyUnicode_GetLength[USize](str: Pointer[U8] box)
use @PyUnicode_AsUTF8[Pointer[U8]](str: Pointer[U8] box)
use @PyUnicode_AsUTF8AndSize[Pointer[U8]](str: Pointer[U8] tag, size: Pointer[ISize] box)
use @PyUnicode_FromStringAndSize[Pointer[U8]](str: Pointer[U8] tag, size: USize)
use @PyList_New[Pointer[U8] val](size: USize)
use @PyList_Size[USize](l: Pointer[U8] box)
use @PyList_GetItem[Pointer[U8] val](l: Pointer[U8] box, i: USize)
use @PyList_SetItem[I32](l: Pointer[U8] box, i: USize, item: Pointer[U8] box)
use @PyLong_AsLong[I64](i: Pointer[U8] box)
use @PyObject_HasAttrString[I32](o: Pointer[U8] box, attr: Pointer[U8] tag)

type CString is Pointer[U8] tag

type ModuleP is Pointer[U8] val

class val PyData
  var _data: Pointer[U8] val

  new val create(data: Pointer[U8] val) =>
    _data = data

  fun obj(): Pointer[U8] val =>
    _data

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_data)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_data, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _data = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_data)

class PyState is State
  var _state: Pointer[U8] val

  new create(state: Pointer[U8] val) =>
    _state = state

  fun obj(): Pointer[U8] val =>
    _state

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_state)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_state, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _state = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_state)

class val PyKeyExtractor
  var _key_extractor: Pointer[U8] val

  new val create(key_extractor: Pointer[U8] val) =>
    _key_extractor = key_extractor

  fun apply(data: PyData val): String =>
    recover
      let ps = Machida.extract_key(_key_extractor, data.obj())
      Machida.print_errors()

      if ps.is_null() then
        @printf[I32]("Error in key extractor function".cstring())
        Fail()
      end

      let ret = Machida.py_bytes_or_unicode_to_pony_string(ps)

      Machida.dec_ref(ps)

      ret
    end

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_key_extractor)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_key_extractor, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _key_extractor = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_key_extractor)

class PySourceHandler is SourceHandler[(PyData val | None)]
  var _source_decoder: Pointer[U8] val

  new create(source_decoder: Pointer[U8] val) =>
    _source_decoder = source_decoder

  fun decode(data: Array[U8] val): (PyData val | None) =>
    let r = Machida.source_decoder_decode(_source_decoder, data.cpointer(),
        data.size())
    if not Machida.is_py_none(r) then
      PyData(r)
    else
      None
    end

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_source_decoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_source_decoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _source_decoder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_source_decoder)

class PyFramedSourceHandler is FramedSourceHandler[(PyData val | None)]
  var _source_decoder: Pointer[U8] val
  let _header_length: USize

  new create(source_decoder: Pointer[U8] val) ? =>
    _source_decoder = source_decoder
    let hl = Machida.framed_source_decoder_header_length(_source_decoder)
    if (Machida.err_occurred()) or (hl == 0) then
      @printf[U32]("ERROR: _header_length %d is invalid\n".cstring(), hl)
      error
    else
      _header_length = hl
    end

  fun header_length(): USize =>
    _header_length

  fun payload_length(data: Array[U8] iso): USize =>
    Machida.framed_source_decoder_payload_length(_source_decoder, data.cpointer(),
      data.size())

  fun decode(data: Array[U8] val): (PyData val | None) =>
    let r = Machida.source_decoder_decode(_source_decoder, data.cpointer(),
        data.size())
    if not Machida.is_py_none(r) then
      PyData(r)
    else
      None
    end

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_source_decoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_source_decoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _source_decoder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_source_decoder)

class val PyGenSourceHandlerBuilder
  var _source_generator: Pointer[U8] val

  new create(source_generator: Pointer[U8] val) =>
    _source_generator = source_generator

  fun apply(): PyGenSourceHandler =>
    PyGenSourceHandler(_source_generator)

class PyGenSourceHandler is GenSourceGenerator[PyData val]
  var _source_generator: Pointer[U8] val

  new create(source_generator: Pointer[U8] val) =>
    _source_generator = source_generator

  fun initial_value(): (PyData val | None) =>
    let r = Machida.source_generator_initial_value(_source_generator)
    if not Machida.is_py_none(r) then
      PyData(r)
    else
      None
    end

  fun apply(data: PyData val): (PyData val | None) =>
    let r = Machida.source_generator_apply(_source_generator, data.obj())
    if not Machida.is_py_none(r) then
      PyData(r)
    else
      None
    end

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_source_generator)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_source_generator, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _source_generator = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_source_generator)

class val PyComputation is StatelessComputation[PyData val, PyData val]
  var _computation: Pointer[U8] val
  let _name: String
  let _is_multi: Bool

  new val create(computation: Pointer[U8] val) =>
    _computation = computation
    _name = Machida.get_name(_computation)
    _is_multi = Machida.implements_compute_multi(_computation)

  fun apply(input: PyData val): (PyData val | Array[PyData val] val | None) =>
    let r: Pointer[U8] val =
      Machida.computation_compute(_computation, input.obj(), _is_multi)

    if not Machida.is_py_none(r) then
      Machida.process_computation_results(r, _is_multi)
    else
      None
    end

  fun name(): String =>
    _name

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_computation)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_computation, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_computation)

class PyStateComputation is StateComputation[PyData val, PyData val, PyState]
  var _computation: Pointer[U8] val
  let _name: String
  let _is_multi: Bool

  new create(computation: Pointer[U8] val) =>
    _computation = computation
    _name = Machida.get_name(_computation)
    _is_multi = Machida.implements_compute_multi(_computation)

  fun apply(input: PyData val, state: PyState):
    (PyData val | Array[PyData val] val | None)
  =>
    let data =
      Machida.stateful_computation_compute(_computation, input.obj(),
        state.obj(), _is_multi)

    let d = recover if Machida.is_py_none(data) then
        Machida.dec_ref(data)
        None
      else
        Machida.process_computation_results(data, _is_multi)
      end
    end

    d

  fun name(): String =>
    _name

  fun initial_state(): PyState =>
    Machida.initial_state(_computation)

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_computation)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_computation, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_computation)

class val PyAggregation is
  Aggregation[PyData val, (PyData val | None), PyState]
  var _aggregation: Pointer[U8] val
  let _name: String

  new val create(aggregation: Pointer[U8] val) =>
    _aggregation = aggregation
    _name = Machida.get_name(_aggregation)

  fun initial_accumulator(): PyState =>
    Machida.initial_accumulator(_aggregation)

  fun update(data: PyData val, acc: PyState) =>
    Machida.aggregation_update(_aggregation, data.obj(), acc.obj())

  fun combine(acc1: PyState, acc2: PyState): PyState =>
    Machida.aggregation_combine(_aggregation, acc1.obj(), acc2.obj())

  fun output(key: Key, acc: PyState): (PyData val | None) =>
    let data =
      Machida.aggregation_output(_aggregation, key.cstring(), acc.obj())

    recover if Machida.is_py_none(data) then
        Machida.dec_ref(data)
        None
      else
        PyData(data)
      end
    end

  fun name(): String =>
    _name

class PyTCPEncoder is TCPSinkEncoder[PyData val]
  var _sink_encoder: Pointer[U8] val

  new create(sink_encoder: Pointer[U8] val) =>
    _sink_encoder = sink_encoder

  fun apply(data: PyData val, wb: Writer): Array[ByteSeq] val =>
    let byte_buffer = Machida.sink_encoder_encode(_sink_encoder, data.obj())
    if not Machida.is_py_none(byte_buffer) then
      let byte_string = @py_bytes_or_unicode_as_char(byte_buffer)

      if not byte_string.is_null() then
        let arr = recover val
          // create a temporary Array[U8] wrapper for the C array, then clone it
          Machida.py_bytes_or_unicode_to_pony_array(byte_buffer)
        end
        Machida.dec_ref(byte_buffer)
        wb.write(arr)
      else
        Machida.print_errors()
        Fail()
      end
    end
    wb.done()

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_sink_encoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_sink_encoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _sink_encoder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_sink_encoder)

class PyKafkaEncoder is KafkaSinkEncoder[PyData val]
  var _sink_encoder: Pointer[U8] val

  new create(sink_encoder: Pointer[U8] val) =>
    _sink_encoder = sink_encoder

  fun apply(data: PyData val, wb: Writer):
    (Array[ByteSeq] val, (Array[ByteSeq] val | None), (None | KafkaPartitionId))
  =>
    let out_and_key_and_part_id = Machida.sink_encoder_encode(_sink_encoder, data.obj())
    // `out_and_key_and_part_id` is a tuple of `(out, key, part_id)`, where `out` is a
    // string and key is `None` or a string and `part_id` is `None` or a KafkaPartitionId.
    let out_p = @PyTuple_GetItem(out_and_key_and_part_id, 0)
    let key_p = @PyTuple_GetItem(out_and_key_and_part_id, 1)
    let part_id_p = @PyTuple_GetItem(out_and_key_and_part_id, 2)

    let out = wb.>write(recover val
        // create a temporary Array[U8] wrapper for the C array, then clone it
        Machida.py_bytes_or_unicode_to_pony_array(out_p)
      end).done()

    let key = if Machida.is_py_none(key_p) then
        None
      else
        wb.>write(recover
          Machida.py_bytes_or_unicode_to_pony_array(key_p)
        end).done()
      end

    let part_id = if Machida.is_py_none(part_id_p) then
        None
      else
        @PyLong_AsLong(part_id_p).i32()
      end

    Machida.dec_ref(out_and_key_and_part_id)

    (consume out, consume key, part_id)

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_sink_encoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_sink_encoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _sink_encoder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_sink_encoder)


class PyConnectorEncoder is ConnectorSinkEncoder[PyData val]
  var _sink_encoder: Pointer[U8] val

  new create(sink_encoder: Pointer[U8] val) =>
    _sink_encoder = sink_encoder

  fun apply(data: PyData val, wb: Writer): Array[ByteSeq] val =>
    let byte_buffer = Machida.sink_encoder_encode(_sink_encoder, data.obj())
    if not Machida.is_py_none(byte_buffer) then
      let byte_string = @py_bytes_or_unicode_as_char(byte_buffer)

      if not byte_string.is_null() then
        let arr = recover val
          // create a temporary Array[U8] wrapper for the C array, then clone it
          Array[U8].from_cpointer(@py_bytes_or_unicode_as_char(byte_buffer),
            @PyBytes_Size(byte_buffer)).clone()
        end
        Machida.dec_ref(byte_buffer)
        wb.write(arr)
      else
        Machida.print_errors()
        Fail()
      end
    end
    wb.done()

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_sink_encoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_sink_encoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _sink_encoder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_sink_encoder)


primitive Machida
  fun print_errors(): Bool =>
    if err_occurred() then
      @PyErr_Print[None]()
      true
    else
      false
    end

  fun err_occurred(): Bool =>
    let er = @PyErr_Occurred[Pointer[U8]]()
    if not er.is_null() then
      true
    else
      false
    end

  fun start_python() =>
    @Py_Initialize()

  fun load_module(module_name: String): ModuleP ? =>
    let r = @load_module(module_name.cstring())
    if print_errors() then
      error
    end
    r

  fun application_setup(module: ModuleP, args: Array[String] val):
    Pointer[U8] val ?
  =>
    let pyargs = Machida.pony_array_string_to_py_list_string(args)
    let r = @application_setup(module, pyargs)
    if print_errors() then
      error
    end
    r

  fun apply_application_setup(application_setup_data: Pointer[U8] val,
    env: Env): (String, Pipeline[PyData val] val) ?
  =>
    recover val
      let pipeline_tree = PyPipelineTree(application_setup_data, env)
      let pipeline = pipeline_tree.build()?
      (pipeline_tree.app_name, pipeline)
    end

  fun framed_source_decoder_header_length(source_decoder: Pointer[U8] val): USize =>
    @PyErr_Clear[None]()
    let r = @source_decoder_header_length(source_decoder)
    print_errors()
    if (r >= 1) and (r <= 8) then
      r
    else
      @printf[U32]("ERROR: header_length() method returned invalid size\n".cstring())
      4
    end

  fun framed_source_decoder_payload_length(source_decoder: Pointer[U8] val,
    data: Pointer[U8] tag, size: USize): USize
  =>
    @PyErr_Clear[None]()
    let r = @source_decoder_payload_length(source_decoder, data, size)
    if err_occurred() then
      print_errors()
      4
    else
      r
    end

  fun source_decoder_decode(source_decoder: Pointer[U8] val,
    data: Pointer[U8] tag, size: USize): Pointer[U8] val
  =>
    let r = @source_decoder_decode(source_decoder, data, size)
    print_errors()
    if r.is_null() then Fail() end
    r

  fun source_generator_initial_value(source_decoder: Pointer[U8] val):
    Pointer[U8] val
  =>
    let r = @source_generator_initial_value(source_decoder)
    print_errors()
    if r.is_null() then Fail() end
    r

  fun source_generator_apply(source_decoder: Pointer[U8] val,
    data: Pointer[U8] val): Pointer[U8] val
  =>
    let r = @source_generator_apply(source_decoder, data)
    print_errors()
    if r.is_null() then Fail() end
    r

  fun sink_encoder_encode(sink_encoder: Pointer[U8] val, data: Pointer[U8] val):
    Pointer[U8] val
  =>
    let r = @sink_encoder_encode(sink_encoder, data)
    print_errors()
    if r.is_null() then Fail() end
    r

  fun computation_compute(computation: Pointer[U8] val, data: Pointer[U8] val,
    multi: Bool): Pointer[U8] val
  =>
    let method = if multi then "compute_multi" else "compute" end
    let r = @computation_compute(computation, data, method.cstring())
    print_errors()
    if r.is_null() then Fail() end
    r

  fun stateful_computation_compute(computation: Pointer[U8] val,
    data: Pointer[U8] val, state: Pointer[U8] val, multi: Bool):
    Pointer[U8] val
  =>
    let method = if multi then "compute_multi" else "compute" end
    let r =
      @stateful_computation_compute(computation, data, state, method.cstring())

    print_errors()
    if r.is_null() then Fail() end
    r

  fun initial_state(computation: Pointer[U8] val): PyState =>
    PyState(@initial_state(computation))

 fun initial_accumulator(aggregation: Pointer[U8] val): PyState =>
    PyState(@initial_accumulator(aggregation))

  fun aggregation_update(aggregation: Pointer[U8] val, data: Pointer[U8] val,
    acc: Pointer[U8] val)
  =>
    @aggregation_update(aggregation, data, acc)

  fun aggregation_combine(aggregation: Pointer[U8] val, acc1: Pointer[U8] val,
    acc2: Pointer[U8] val): PyState
  =>
    PyState(@aggregation_combine(aggregation, acc1, acc2))

  fun aggregation_output(aggregation: Pointer[U8] val, key: Pointer[U8] tag,
    acc: Pointer[U8] val): Pointer[U8] val
  =>
    @aggregation_output(aggregation, key, acc)

  fun key_hash(key: Pointer[U8] val): USize =>
    let r = @key_hash(key)
    print_errors()
    r.usize()

  fun key_eq(key: Pointer[U8] val, other: Pointer[U8] val): Bool =>
    let r = not (@key_eq(key, other) == 0)
    print_errors()
    r

  fun extract_key(key_extractor: Pointer[U8] val,
    data: Pointer[U8] val): Pointer[U8] val
  =>
    let r = @extract_key(key_extractor, data)
    print_errors()
    if r.is_null() then Fail() end
    r

  fun py_list_to_pony_array_string(py_array: Pointer[U8] val):
    Array[String] val
  =>
    let size = @PyList_Size(py_array)
    let arr = recover iso Array[String](size) end

    for i in Range(0, size) do
      arr.push(Machida.py_bytes_or_unicode_to_pony_string(@PyList_GetItem(py_array, i)))
    end

    consume arr

  fun py_list_to_filtered_pony_array_pydata(py_array: Pointer[U8] val):
    (Array[PyData val] val | None)
  =>
    let size = @PyList_Size(py_array)
    let arr = recover iso Array[PyData val](size) end

    for i in Range(0, size) do
      let obj = @PyList_GetItem(py_array, i)
      if not Machida.is_py_none(obj) then
        Machida.inc_ref(obj)
        arr.push(PyData(obj))
      end
    end
    if arr.size() == 0 then
      None
    else
      arr.compact()
      consume arr
    end

  fun pony_array_string_to_py_list_string(args: Array[String] val):
    Pointer[U8] val
  =>
    let l = @PyList_New(args.size())
    for (i, v) in args.pairs() do
      @PyList_SetItem(l, i, @PyUnicode_FromStringAndSize(v.cstring(), v.size()))
    end
    l

  fun get_name(o: Pointer[U8] val): String =>
    let ps = @get_name(o)
    recover
      if not ps.is_null() then
        let ret = Machida.py_bytes_or_unicode_to_pony_string(ps)
        dec_ref(ps)
	      ret
      else
        "undefined-name"
      end
    end

  fun py_bytes_or_unicode_to_pony_string(p: Pointer[U8] box): String =>
    recover
      var ps: Pointer[U8] = Pointer[U8]
      var ps_size: ISize = 0
      var err: I32 = 0
      if @py_bytes_check(p) == 0 then
        ps = @PyUnicode_AsUTF8AndSize(p, addressof ps_size)
      else
        err = @PyBytes_AsStringAndSize(p, addressof ps,  addressof ps_size)
      end
      if (err != 0) or ps.is_null() then
        @printf[U32]("unexpected non-string value\n".cstring())
        print_errors()
        Fail()
        String
      elseif ps_size < 0 then
        String
      else
        String.copy_cpointer(ps, ps_size.usize())
      end
    end

    fun py_bytes_or_unicode_to_pony_array(p: Pointer[U8] box): Array[U8] iso^ =>
      recover
        var ps: Pointer[U8] = Pointer[U8]
        var ps_size: ISize = 0
        var err: I32 = 0
        if @py_bytes_check(p) == 0 then
          ps = @PyUnicode_AsUTF8AndSize(p, addressof ps_size)
        else
          err = @PyBytes_AsStringAndSize(p, addressof ps, addressof ps_size)
        end
        if (err != 0) or ps.is_null() then
          @printf[U32]("unexpected non-string value\n".cstring())
          print_errors()
          Fail()
          Array[U8]
        elseif ps_size < 0 then
          Array[U8]
        else
          Array[U8].from_cpointer(ps, ps_size.usize()).clone()
        end
      end



  fun set_user_serialization_fns(m: Pointer[U8] val) =>
    @set_user_serialization_fns(m)

  fun user_serialization_get_size(o: Pointer[U8] tag): USize =>
    let r = @user_serialization_get_size(o)
    if (print_errors()) then
      FatalUserError("Serialization failed")
    end
    r

  fun user_serialization(o: Pointer[U8] tag, bs: Pointer[U8] tag) =>
    @user_serialization(o, bs)
    if (print_errors()) then
      FatalUserError("Serialization failed")
    end

  fun user_deserialization(bs: Pointer[U8] tag): Pointer[U8] val =>
    let r = @user_deserialization(bs)
    if (print_errors()) then
      FatalUserError("Deserialization failed")
    end
    r

  fun bool_check(b: Pointer[U8] val): Bool =>
    not (@py_bool_check(b) == 0)

  fun is_py_none(o: Pointer[U8] box): Bool =>
    not (@is_py_none(o) == 0)

  fun inc_ref(o: Pointer[U8] box) =>
    @py_incref(o)

  fun dec_ref(o: Pointer[U8] box) =>
    @py_decref(o)

  fun process_computation_results(data: Pointer[U8] val, multi: Bool):
    (PyData val | Array[PyData val] val | None)
  =>
    if not multi then
      PyData(data)
    else
      if @py_list_check(data) == 1 then
        let out = Machida.py_list_to_filtered_pony_array_pydata(data)
        Machida.dec_ref(data)
        out
      else
        @printf[U32]("compute_multi must return a list\n".cstring())
        Fail()
        recover val Array[PyData val] end
      end
    end

  fun implements_compute_multi(o: Pointer[U8] box): Bool =>
    implements_method(o, "compute_multi")

  fun implements_method(o: Pointer[U8] box, method: String): Bool =>
    @PyObject_HasAttrString(o, method.cstring()) == 1

primitive _SourceConfig
  fun from_tuple(source_config_tuple: Pointer[U8] val, env: Env):
    SourceConfig ?
  =>
    let name = recover val
      Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 0))
    end

    match name
    | "gen" =>
      let gen = recover val
        let g = @PyTuple_GetItem(source_config_tuple, 1)
        Machida.inc_ref(g)
        PyGenSourceHandlerBuilder(g)
      end
      GenSourceConfig[PyData val](gen)
    | "tcp" =>
      let host = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 1))
      end

      let port = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 2))
      end

      let decoder = recover val
        let d = @PyTuple_GetItem(source_config_tuple, 3)
        Machida.inc_ref(d)
        PyFramedSourceHandler(d)?
      end

      let parallelism = recover val
        USize.from[I64](@PyLong_AsLong(@PyTuple_GetItem(source_config_tuple, 4)))
      end

      TCPSourceConfig[(PyData val | None)](decoder, host, port, parallelism)
    | "kafka-internal" =>
      let kafka_source_name = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 1))
      end

      let ksclip = KafkaSourceConfigCLIParser(env.out, kafka_source_name)
      let ksco = ksclip.parse_options(env.args)?

      let decoder = recover val
        let d = @PyTuple_GetItem(source_config_tuple, 2)
        Machida.inc_ref(d)
        PySourceHandler(d)
      end

      KafkaSourceConfig[(PyData val | None)](consume ksco, (env.root as TCPConnectionAuth), decoder)
    | "kafka" =>
      let ksco = _kafka_config_options(source_config_tuple)

      let decoder = recover val
        let d = @PyTuple_GetItem(source_config_tuple, 4)
        Machida.inc_ref(d)
        PySourceHandler(d)
      end

      KafkaSourceConfig[(PyData val | None)](consume ksco, (env.root as TCPConnectionAuth), decoder)
    | "source_connector" =>
      let host = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 2))
      end

      let port = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 3))
      end

      let decoder = recover val
        let d = @PyTuple_GetItem(source_config_tuple, 5)
        Machida.inc_ref(d)
        PyFramedSourceHandler(d)?
      end

      ConnectorSourceConfig[(PyData val | None)](decoder, host, port)
    else
      error
    end

  fun _kafka_config_options(source_config_tuple: Pointer[U8] val): KafkaConfigOptions iso^ =>
    let topic = recover val
      Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 1))
    end

    let brokers_list = @PyTuple_GetItem(source_config_tuple, 2)

    let brokers = recover val
      let num_brokers = @PyList_Size(brokers_list)
      let brokers' = Array[(String, I32)](num_brokers)

      for i in Range(0, num_brokers) do
        let broker = @PyList_GetItem(brokers_list, i)
        let host = recover val
          Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(broker, 0))
        end
        let port = try
          Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(broker, 1)).i32()?
        else
          9092
        end
        brokers'.push((host, port))
      end
      brokers'
    end

    let log_level = recover val
      Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 3))
    end

    KafkaConfigOptions("Wallaroo Kafka Source", KafkaConsumeOnly, topic, brokers, log_level)

primitive _SinkConfig
  fun from_tuple(sink_config_tuple: Pointer[U8] val, env: Env):
    SinkConfig[PyData val] ?
  =>
    let name = recover val
      Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(sink_config_tuple, 0))
    end

    match name
    | "tcp" =>
      let host = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(sink_config_tuple, 1))
      end

      let port = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(sink_config_tuple, 2))
      end

      let encoderp = @PyTuple_GetItem(sink_config_tuple, 3)
      Machida.inc_ref(encoderp)
      let encoder = recover val
        PyTCPEncoder(encoderp)
      end

      TCPSinkConfig[PyData val](encoder, host, port)
    | "kafka-internal" =>
      let kafka_sink_name = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(sink_config_tuple, 1))
      end

      let encoderp = @PyTuple_GetItem(sink_config_tuple, 2)
      Machida.inc_ref(encoderp)
      let encoder = recover val
        PyKafkaEncoder(encoderp)
      end

      let ksclip = KafkaSinkConfigCLIParser(env.out, kafka_sink_name)
      let ksco = ksclip.parse_options(env.args)?

      KafkaSinkConfig[PyData val](encoder, consume ksco, (env.root as TCPConnectionAuth))
    | "kafka" =>
      let ksco = _kafka_config_options(sink_config_tuple)

      let encoderp = @PyTuple_GetItem(sink_config_tuple, 6)
      Machida.inc_ref(encoderp)
      let encoder = recover val
        PyKafkaEncoder(encoderp)
      end

      KafkaSinkConfig[PyData val](encoder, consume ksco, (env.root as TCPConnectionAuth))
    | "sink_connector" =>
      let host = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(sink_config_tuple, 2))
      end

      let port = recover val
        Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(sink_config_tuple, 3))
      end

      let encoderp = @PyTuple_GetItem(sink_config_tuple, 4)
      Machida.inc_ref(encoderp)
      let encoder = recover val
        PyConnectorEncoder(encoderp)
      end

      ConnectorSinkConfig[PyData val](encoder, host, port)
    else
      error
    end

  fun _kafka_config_options(source_config_tuple: Pointer[U8] val): KafkaConfigOptions iso^ =>
    let topic = recover val
      Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 1))
    end

    let brokers_list = @PyTuple_GetItem(source_config_tuple, 2)

    let brokers = recover val
      let num_brokers = @PyList_Size(brokers_list)
      let brokers' = Array[(String, I32)](num_brokers)

      for i in Range(0, num_brokers) do
        let broker = @PyList_GetItem(brokers_list, i)
        let host = recover val
          Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(broker, 0))
        end
        let port = try
          Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(broker, 1)).i32()?
        else
          9092
        end
        brokers'.push((host, port))
      end
      brokers'
    end

    let log_level = recover val
      Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source_config_tuple, 3))
    end

    let max_produce_buffer_ms = @PyLong_AsLong(@PyTuple_GetItem(source_config_tuple, 4)).u64()

    let max_message_size = @PyLong_AsLong(@PyTuple_GetItem(source_config_tuple, 5)).i32()

    KafkaConfigOptions("Wallaroo Kafka Sink", KafkaProduceOnly, topic, brokers, log_level, max_produce_buffer_ms, max_message_size)

  class val PyPipelineTree
    """
    A read-only tree of pipeline fragments. Each node is a list of stages, each
    one either beginning with a source_config or a "merge" command. The tree
    represents the recursive merges of pipelines starting with sources.
    """
    let env: Env
    // Each member of this array is a list of stages. Each of these lists will
    // either begin with a "source" stage (if it is a leaf of the tree) or
    // a "merge" stage (if it is not a leaf).
    let vs: Array[Pointer[U8] val] val
    // This list of list of edges represents the out-edges for each element
    // in the vs array. Each element in vs should have either 0 or 2 out edges.
    // This is because each element is either a leaf (representing a source
    // plus 0 or more stages following it) or a merge of two pipeline fragments
    // (plus 0 or more stages following the merge in sequence).
    let es: Array[Array[USize] val] val
    let root_idx: USize
    let app_name: String

    new val create(p_graph: Pointer[U8] val, env': Env) =>
      env = env'

      // p_graph points to a tuple of the form:
      // (app_name, root_idx, vertices, edges)
      app_name =
        recover val
          let ps = @PyTuple_GetItem(p_graph, 0)
          Machida.py_bytes_or_unicode_to_pony_string(ps)
        end
      root_idx = @PyLong_AsLong(@PyTuple_GetItem(p_graph, 1)).usize()
      let stage_vs = @PyTuple_GetItem(p_graph, 2)
      let stage_es = @PyTuple_GetItem(p_graph, 3)

      // Extract list of stage vertices
      vs =
        recover val
          let arr = Array[Pointer[U8] val]
          let vs_size = @list_item_count(stage_vs)
          for i in Range(0, vs_size) do
            let next_v = @get_list_item(stage_vs, i)
            arr.push(next_v)
          end
          arr
        end

      // Extract list of edges
      es =
        recover val
          let arr = Array[Array[USize] val]
          let es_size = @list_item_count(stage_es)
          for i in Range(0, es_size) do
            let next_es = recover iso Array[USize] end
            let next_e_list = @get_list_item(stage_es, i)
            let next_e_list_size = @list_item_count(next_e_list)
            if not ((next_e_list_size == 0) or (next_e_list_size == 2)) then
              @printf[I32](("Each node in the Machida pipeline tree should " +
                "have either 0 or 2 children, but one node had %s\n")
                .cstring(), next_e_list_size.string().cstring())
              Fail()
            end
            for j in Range(0, next_e_list_size) do
              let next_out_edge =
                @PyLong_AsLong(@get_list_item(next_e_list, j)).usize()
              next_es.push(next_out_edge)
            end
            arr.push(consume next_es)
          end
          arr
        end

    fun build(): Pipeline[PyData val] ? =>
      // Recursively build the pipeline.
      _build_from(root_idx)?

    fun _build_from(idx: USize): Pipeline[PyData val] ? =>
      let stages = vs(idx)?
      let edges = es(idx)?
      if edges.size() == 0 then
        // This node is a leaf, which means it begins with a source. Start the
        // pipeline with the source.
        let source = @get_list_item(stages, 0)
        let source_name = recover val
          Machida.py_bytes_or_unicode_to_pony_string(@PyTuple_GetItem(source,
            1)) end
        let source_config = @PyTuple_GetItem(source, 2)
        var pipeline = Wallaroo.source[PyData val](source_name,
          _SourceConfig.from_tuple(source_config, env)?)

        let stages_size = @list_item_count(stages)
        if stages_size > 1 then
          // Do some stage building starting after the source
          for i in Range(1, stages_size) do
            let next_stage = @get_list_item(stages, i)
            pipeline = _add_next_stage(pipeline, next_stage)?
          end
        end
        pipeline
      else
        // Build left pipeline
        var pipeline = _build_from(edges(0)?)?
        // Merge with right pipeline
        pipeline = pipeline.merge[PyData val](_build_from(edges(1)?)?)
        // Do some stage building starting after the merge.
        // There might not be any stages immediately after the merge.
        let stages_size = @list_item_count(stages)
        if stages_size > 0 then
          // Do some stage building starting after the merge.
          for i in Range(0, stages_size) do
            let next_stage = @get_list_item(stages, i)
            pipeline = _add_next_stage(pipeline, next_stage)?
          end
        end
        pipeline
      end

    fun _add_next_stage(p: Pipeline[PyData val], stage: Pointer[U8] val):
      Pipeline[PyData val] ?
    =>
      var pipeline = p
      // let command_p = @get_stage_command(stage)
      // let command = Machida.py_bytes_or_unicode_to_pony_string(command_p)
      let command = Machida.py_bytes_or_unicode_to_pony_string(
        @PyTuple_GetItem(stage, 0))
      match command
      | "to" =>
        let raw_computation = @PyTuple_GetItem(stage, 1)
        let computation = PyComputation(raw_computation)
        Machida.inc_ref(raw_computation)
        pipeline = pipeline.to[PyData val](computation)
      | "to_state" =>
        let state_computationp = @PyTuple_GetItem(stage, 1)
        Machida.inc_ref(state_computationp)
        let state_computation = recover val
          PyStateComputation(state_computationp)
        end
        pipeline = pipeline.to[PyData val](state_computation)
      | "to_range_windows" =>
        let range = @PyLong_AsLong(@PyTuple_GetItem(stage, 1)).u64()
        let slide = @PyLong_AsLong(@PyTuple_GetItem(stage, 2)).u64()
        let delay = @PyLong_AsLong(@PyTuple_GetItem(stage, 3)).u64()
        let raw_aggregation = @PyTuple_GetItem(stage, 4)
        let aggregation = PyAggregation(raw_aggregation)
        Machida.inc_ref(raw_aggregation)
        let windows = Wallaroo.range_windows(range)
                                .with_slide(slide)
                                .with_delay(delay)
                                .over[PyData val, PyData val, PyState](
                                  aggregation)
        pipeline = pipeline.to[PyData val](windows)
      | "key_by" =>
        let raw_key_extractor = @PyTuple_GetItem(stage, 1)
        let key_extractor = PyKeyExtractor(raw_key_extractor)
        Machida.inc_ref(raw_key_extractor)
        pipeline = pipeline.key_by(key_extractor)
      | "collect" =>
        pipeline = pipeline.collect()
      | "to_sink" =>
        pipeline = pipeline.to_sink(
          _SinkConfig.from_tuple(@PyTuple_GetItem(stage, 1), env)?)
      | "to_sinks" =>
        let list = @PyTuple_GetItem(stage, 1)
        let sink_count = @PyList_Size(list)
        let sinks = Array[SinkConfig[PyData val]]
        for i in Range(0, sink_count) do
          let sink = _SinkConfig.from_tuple(@PyList_GetItem(list, i), env)?
          sinks.push(sink)
        end
        pipeline = pipeline.to_sinks(sinks)
      end
      pipeline


