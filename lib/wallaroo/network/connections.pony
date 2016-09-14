use "collections"
use "net"

actor Connections
  let control_conns: Map[String, TCPConnection] = control_conns.create()
  let data_conns: Map[String, TCPConnection] = data_conns.create()

  be add_control_connection(node: String, conn: TCPConnection) =>
    control_conns(node) = conn

  be add_data_connection(node: String, conn: TCPConnection) =>
    data_conns(node) = conn

  be send_control(node: String, data: Array[ByteSeq] val) =>
    try
      control_conns(node).writev(data)
    else
      @printf[I32](("No control connection for node " + node + "\n").cstring())
    end

  be send_data(node: String, data: Array[ByteSeq] val) =>
    try
      data_conns(node).writev(data)
    else
      @printf[I32](("No data connection for node " + node + "\n").cstring())
    end
