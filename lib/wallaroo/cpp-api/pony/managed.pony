use @w_managed_object_delete[None](obj: ManagedObjectP)
use @w_hashable_hash[U64](obj: ManagedObjectP)
use @w_hashable_partition_index[U64](obj: ManagedObjectP)

type ManagedObjectP is Pointer[U8] val

class CPPManagedObject
  var _obj: ManagedObjectP

  new create(obj': ManagedObjectP) =>
    _obj = obj'

  fun obj(): ManagedObjectP =>
    _obj

  fun _final() =>
    @w_managed_object_delete(_obj)

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(obj())

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(obj(), bytes, USize(0))

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _obj = @w_user_serializable_deserialize(bytes, USize(0))

  fun hash(): U64 =>
    @w_hashable_hash(_obj)
    _obj.usize().u64()

  fun eq(other: CPPManagedObject): Bool =>
    _obj.hash() == other.hash()

  fun partition_index(): U64 =>
    @w_hashable_partition_index(_obj)
    0
