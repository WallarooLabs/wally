

use "wallaroo/core/common"

class val BoundaryEdge is Equatable[BoundaryEdge]
  let input: StepId
  let output: StepId

  new val create(i: StepId, o: StepId) =>
    input = i
    output = o

  fun eq(that: box->BoundaryEdge): Bool =>
    (input == that.input) and (output == that.output)

  fun hash(): USize =>
    input.hash() xor output.hash()
