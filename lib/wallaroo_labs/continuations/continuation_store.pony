use "collections"
use "../guid"
use "../mort"

actor ContinuationStore[T: Any #send]
  """
  The `ContinuationStore` stores functions that can be called later to
  continue processing with a resource. The continuations are
  associated with a ID which can be used later to call the associated
  continuation. Once the continuation is applied it is removed from the
  store.
  """
  var _guid_generator: GuidGenerator = GuidGenerator
  let _continuations: Map[U128, {(T)} val] =
    _continuations.create()

  be insert(continuation: {(T)} val, with_id: {(U128)} val) =>
    let this_id = _guid_generator.u128()
    _continuations(this_id) = continuation
    with_id(this_id)

  be apply(id: U128, arg: T) =>
    try
      let c = _continuations(id)?
      _continuations.remove(id)?
      c(consume arg)
    else
      Fail()
    end
