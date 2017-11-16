use "collections"

use @PartitionFunctionU64Partition[U64](pid: U64, did: U64)
use @PartitionListU64GetSize[U64](plid: U64)
use @PartitionListU64GetItem[U64](plid: U64, idx: U64)

class val PartitionFunctionU64
  var _partition_function_id: U64

  new val create(partition_function_id: U64) =>
    _partition_function_id = partition_function_id

  fun apply(data: GoData val): U64 =>
    @PartitionFunctionU64Partition(_partition_function_id, data.id())

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_partition_function_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_partition_function_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _partition_function_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_partition_function_id)

primitive PartitionListU64
  fun apply(plid: U64): Array[U64] val =>
    let partition_list_size = @PartitionListU64GetSize(plid)

    let partition_list = recover trn Array[U64](partition_list_size.usize()) end

    for i in Range[U64](0, partition_list_size) do
      partition_list.push(@PartitionListU64GetItem(plid, i))
    end

    consume partition_list
