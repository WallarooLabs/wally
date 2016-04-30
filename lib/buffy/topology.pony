use "collections"
use "net"

class Topology
  // A sequence of computation type ids representing
  // the computation pipeline
  let pipeline: Array[I32] val

  new val create(p: Array[I32] val) =>
    pipeline = p

trait StepBuilder
  fun val apply(id: I32): Any tag ?
