use "collections"

use @PartitionFunctionPartition[Pointer[U8] val](pid: U64, did: U64, sz: Pointer[U64])
use @PartitionListGetSize[U64](plid: U64)
use @PartitionListGetItem[Pointer[U8] val](plid: U64, idx: U64, sz: Pointer[U64])

class val PartitionFunction
  var _partition_function_id: U64

  new val create(partition_function_id: U64) =>
    _partition_function_id = partition_function_id

  fun apply(data: GoData val): String =>
    var sz: U64 = 0
    let sp = @PartitionFunctionPartition(_partition_function_id, data.id(), addressof sz)
    recover
      let s = String.copy_cpointer(sp, sz.usize())
      @free(sp)
      s
    end

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_partition_function_id, ComponentType.partition_function())

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_partition_function_id, bytes, ComponentType.partition_function())

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _partition_function_id = ComponentDeserialize(bytes, ComponentType.partition_function())

  fun _final() =>
    RemoveComponent(_partition_function_id, ComponentType.partition_function())

primitive PartitionList
  fun apply(plid: U64): Array[String] val =>
    let partition_list_size = @PartitionListGetSize(plid)

    let partition_list = recover trn Array[String](partition_list_size.usize()) end

    for i in Range[U64](0, partition_list_size) do
      var sz: U64 = 0
      let sp = @PartitionListGetItem(plid, i, addressof sz)
      partition_list.push(recover String.copy_cpointer(sp, sz.usize()) end)
      @free(sp)
    end

    consume partition_list
