type DataP is Pointer[U8] val

class CPPData
  var _data: Pointer[U8] val

  new create(data: Pointer[U8] val) =>
    _data = data

  fun obj(): DataP val =>
    _data

  fun _serialise_space(): USize =>
    @w_serializable_serialize_get_size(_data)

  fun _serialise(bytes: Pointer[U8] tag) =>
    @w_serializable_serialize(_data, bytes, USize(0))

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _data = recover @w_user_serializable_deserialize(bytes, USize(0)) end

  fun delete_obj() =>
    @w_managed_object_delete(_data)
