use @w_partition_function_partition[KeyP]
  (partition_function: PartitionFunctionP, data: DataP)
use @w_partition_function_u64_partition[U64]
  (partition_function: PartitionFunctionP, data: DataP)

type PartitionFunctionP is Pointer[U8] val

class CPPPartitionFunction
  var _partition_function: PartitionFunctionP

  new create(partition_function: PartitionFunctionP) =>
    _partition_function = partition_function

  fun apply(data: CPPData val): CPPKey val =>
    recover
      CPPKey(@w_partition_function_partition(_partition_function, data.obj()))
    end

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_partition_function)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_partition_function, bytes, USize(0))

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _partition_function = recover
      @w_user_serializable_deserialize(bytes, USize(0))
    end

  fun _final() =>
    @w_managed_object_delete(_partition_function)

class CPPPartitionFunctionU64
  var _partition_function: PartitionFunctionP

  new create(partition_function: PartitionFunctionP) =>
    _partition_function = partition_function

  fun apply(data: CPPData val): U64 =>
    @w_partition_function_u64_partition(_partition_function, data.obj())

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_partition_function)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_partition_function, bytes, USize(0))

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _partition_function = recover
      @w_user_serializable_deserialize(bytes, USize(0))
    end

  fun _final() =>
    @w_managed_object_delete(_partition_function)
