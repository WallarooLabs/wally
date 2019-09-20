use "collections"
use "wallaroo_labs/guid"
use "wallaroo_labs/mort"

actor ConnectionsStore
  var _guid_generator: GuidGenerator = GuidGenerator
  let _promise_map: Map[U128, {(Array[ByteSeq] val)} val] = _promise_map.create()

  be insert(p: {(Array[ByteSeq] val)} val, with_id: {(U128)} val) =>
    let this_id = _guid_generator.u128()
    _promise_map(this_id) = p
    with_id(this_id)

  be apply(id: U128, msg: Array[ByteSeq] val) =>
    try
      let p = _promise_map(id)?
      _promise_map.remove(id)?
      p(msg)
    else
      Fail()
    end
