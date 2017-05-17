use "collections"
use "wallaroo"
use "wallaroo/topology"
use "wallaroo/fail"

use @w_computation_builder_build_computation[ComputationP](fn: ComputationBuilderP)

use @w_partition_get_partition_function[PartitionFunctionP](partition: PartitionP)
use @w_partition_get_number_of_keys[USize](partition: PartitionP)
use @w_partition_get_key[KeyP](partition: PartitionP, idx: USize)

use @w_partition_get_partition_function_u64[PartitionFunctionP](partition: PartitionP)
use @w_partition_get_number_of_keys_u64[USize](partition: PartitionP)
use @w_partition_get_key_u64[U64](partition: PartitionP, idx: USize)

export CPPApplicationBuilder

type ApplicationP is Pointer[U8] val
type ComputationBuilderP is Pointer[U8] val
type StateBuilderP is Pointer[U8] val
type PartitionP is Pointer[U8] val

class CPPComputationBuilder
  let _computation_builder: ComputationBuilderP

  new create(computation_builder: ComputationBuilderP) =>
    _computation_builder = computation_builder

  fun apply(): CPPComputation val =>
    recover CPPComputation(@w_computation_builder_build_computation(_computation_builder)) end

class CPPApplicationBuilder
  var _application: (None | Application) = None
  var _pipeline_builder: (None | PipelineBuilder[CPPData val, CPPData val, CPPData val]) = None

  fun ref create_application(application_name': Pointer[U8] ref) =>
    let application_name: String = String.from_cstring(application_name').clone()
    _application = recover Application(application_name) end

  fun ref new_pipeline(name': Pointer[U8] ref,
    source_decoder': Pointer[U8] val)
  =>
    match _application
    | let app: Application =>
      let name = String.from_cstring(name')
      let source_decoder = recover val CPPSourceDecoder(source_decoder') end
      _pipeline_builder = app.
        new_pipeline[CPPData val, CPPData val](name.clone(), source_decoder)
    end

  fun ref to(computation_builder': ComputationBuilderP) =>
    match _pipeline_builder
    | let pb: PipelineBuilder[CPPData val, CPPData val, CPPData val] =>
      let computation_builder: CPPComputationBuilder val =
        recover CPPComputationBuilder(computation_builder') end
      _pipeline_builder = pb.to[CPPData val](computation_builder)
    end

  fun ref to_stateful(state_computation: StateComputationP,
    state_builder': StateBuilderP,
    state_name': Pointer[U8] ref)
  =>
    match _pipeline_builder
    | let pb: PipelineBuilder[CPPData val, CPPData val, CPPData val] =>
      let state_name: String val = String.from_cstring(state_name').clone()
      let state_builder = recover val CPPStateBuilder(state_builder') end
      let stateful_computation_builder = recover val CPPStateComputation(state_computation) end
      _pipeline_builder = pb.to_stateful[CPPData val, CPPState](
        stateful_computation_builder, state_builder, state_name)
    end

  fun ref to_state_partition(state_computation': StateComputationP,
    state_builder': StateBuilderP,
    state_name': Pointer[U8],
    partition': PartitionP,
    multi_worker: Bool)
  =>
    match _pipeline_builder
    | let pb: PipelineBuilder[CPPData val, CPPData val, CPPData val] =>
      let state_name: String val = String.from_cstring(state_name').clone()
      let state_builder = recover val CPPStateBuilder(state_builder') end
      let state_computation = recover val CPPStateComputation(state_computation') end
      let partition_function = recover val CPPPartitionFunction(
        @w_partition_get_partition_function(partition')
      ) end

      let keys = recover iso Array[CPPKey val] end
      for i in Range(0, @w_partition_get_number_of_keys(partition')) do
        keys.push(recover val CPPKey(@w_partition_get_key(partition', i)) end)
      end

      let partition = Partition[CPPData val, CPPKey val](partition_function, consume keys)

      _pipeline_builder = pb.to_state_partition[CPPData val, CPPKey val, CPPData val, CPPState](
        state_computation,
        state_builder,
        state_name,
        partition,
        multi_worker)
    end

  fun ref to_state_partition_u64(state_computation': StateComputationP,
    state_builder': StateBuilderP,
    state_name': Pointer[U8],
    partition': PartitionP,
    multi_worker: Bool)
  =>
    match _pipeline_builder
    | let pb: PipelineBuilder[CPPData val, CPPData val, CPPData val] =>
      let state_name: String val = String.from_cstring(state_name').clone()
      let state_builder = recover val CPPStateBuilder(state_builder') end
      let state_computation = recover val CPPStateComputation(state_computation') end
      let partition_function = recover val CPPPartitionFunctionU64(
        @w_partition_get_partition_function_u64(partition')
      ) end

      let keys = recover iso Array[U64] end
      for i in Range(0, @w_partition_get_number_of_keys_u64(partition')) do
        keys.push(@w_partition_get_key_u64(partition', i))
      end

      let partition = Partition[CPPData val, U64](partition_function, consume keys)

      _pipeline_builder = pb.to_state_partition[CPPData val, U64, CPPData val, CPPState](
        state_computation,
        state_builder,
        state_name,
        partition,
        multi_worker)
    end

  fun ref to_sink(sink_encoder': SinkEncoderP) =>
    try
      match _pipeline_builder
      | let pb: PipelineBuilder[CPPData val, CPPData val, CPPData val] =>
        let sink_encoder = recover val CPPSinkEncoder(sink_encoder') end
        pb.to_sink(sink_encoder, recover [0] end)
        _pipeline_builder = None
      end
    else
      Fail()
    end

  fun ref done() =>
    try
      match _pipeline_builder
      | let pb: PipelineBuilder[CPPData val, CPPData val, CPPData val] =>
        pb.done()
      end
    else
      Fail()
    end

  fun ref build(): Application ? =>
    _application as Application
