class val GoData
  var _data_id: U64

  new val create(data_id: U64) =>
    _data_id = data_id

  fun id(): U64 =>
    _data_id

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_data_id, ComponentType.data())

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_data_id, bytes, ComponentType.data())

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _data_id = ComponentDeserialize(bytes, ComponentType.data())

  fun _final() =>
    RemoveComponent(_data_id, ComponentType.data())
