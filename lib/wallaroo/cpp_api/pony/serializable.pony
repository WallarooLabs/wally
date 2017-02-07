use @w_serializable_serialize_get_size[USize](data: ManagedObjectP)
use @w_serializable_serialize[None](data: ManagedObjectP,
  bytes: Pointer[U8] tag, size: USize)
use @w_user_serializable_deserialize[ManagedObjectP](bytes: Pointer[U8] tag,
  size: USize)
