use "collections"
use "net"
use "time"
use "buffered"
use "files"
use "wallaroo/network"


primitive TopologyInitializer
  fun apply(topology: Topology val, env: Env, data_addr: Array[String],
    input_addrs: Array[Array[String]] val, 
    output_addr: Array[String], metrics_conn: TCPConnection, 
    expected: USize, init_path: String, worker_count: USize,
    is_initializer: Bool, worker_name: String, connections: Connections,
    initializer: (Initializer | None)) 
  =>
    None
