class BoundaryId is Equatable[BoundaryId]
  let name: String
  let step_id: U128

  new create(n: String, s_id: U128) =>
    name = n
    step_id = s_id

  fun eq(that: box->BoundaryId): Bool =>
    (name == that.name) and (step_id == that.step_id)

  fun hash(): U64 =>
    name.hash() xor step_id.hash()
