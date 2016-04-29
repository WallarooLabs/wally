use "collections"
use "net"

trait Topology
  fun initialize(workers: Map[String, TCPConnection tag],
    worker_addrs: Map[String, (String, String)], step_manager: StepManager)

trait StepBuilder
  fun val apply(id: I32): Any tag ?
