

use "wallaroo/core/common"

class val BoundaryEdge is Equatable[BoundaryEdge]
  let input_id: StepId
  let output_id: StepId

  new val create(i: StepId, o: StepId) =>
    input_id = i
    output_id = o

  fun eq(that: box->BoundaryEdge): Bool =>
    (input_id == that.input_id) and (output_id == that.output_id)

  fun hash(): USize =>
    input_id.hash() xor output_id.hash()
