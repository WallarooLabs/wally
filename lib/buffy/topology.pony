use "collections"
use "net"
use "buffy/messages"

class Topology
  // A sequence of computation type ids representing
  // the computation pipeline
  let pipeline: Array[String] val

  new val create(p: Array[String] val) =>
    pipeline = p

trait StepBuilder
  fun val apply(computation_type: String): Any tag ?
