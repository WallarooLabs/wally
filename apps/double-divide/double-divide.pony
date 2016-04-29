use "net"
use "collections"
use "buffy"
use "buffy/messages"

actor Main
  new create(env: Env) =>
    Startup(env, T, SB)

// User computations
primitive ComputationTypes
  fun identity(): I32 => 0
  fun double(): I32 => 1
  fun halve(): I32 => 2
  fun print(): I32 => 3

class Identity is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    msg

class Double is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data * 2
    Message[I32](msg.id, output)

class Halve is Computation[I32, I32]
  fun apply(msg: Message[I32] val): Message[I32] val^ =>
    let output = msg.data / 2
    Message[I32](msg.id, output)

class Print[A: (OSCEncodable & Stringable)] is FinalComputation[A]
  fun apply(msg: Message[A] val) =>
    @printf[String]((msg.data.string() + "\n").cstring())

primitive SB is StepBuilder
  fun val apply(id: I32): Any tag ? =>
    match id
    | ComputationTypes.identity() => Step[I32, I32](Identity)
    | ComputationTypes.double() => Step[I32, I32](Double)
    | ComputationTypes.halve() => Step[I32, I32](Halve)
    | ComputationTypes.print() =>
      Sink[I32](recover Print[I32] end)
    else
      error
    end

// Topology initialization
primitive T is Topology
  fun initialize(workers: Map[String, TCPConnection tag],
    worker_addrs: Map[String, (String, String)], step_manager: StepManager) =>
    try
      let keys = workers.keys()
      let remote_node_name1: String = keys.next()
      let remote_node_name2: String = keys.next()
      let node2_addr = worker_addrs(remote_node_name2)

      let double_step_id: I32 = 1
      let halve_step_id: I32 = 2
      let halve_to_print_proxy_id: I32 = 3
      let print_step_id: I32 = 4

      let halve_create_msg =
        WireMsgEncoder.spin_up(halve_step_id, ComputationTypes.halve())
      let halve_to_print_proxy_create_msg =
        WireMsgEncoder.spin_up_proxy(halve_to_print_proxy_id,
          print_step_id, remote_node_name2, node2_addr._1, node2_addr._2)
      let print_create_msg =
        WireMsgEncoder.spin_up(print_step_id, ComputationTypes.print())
      let connect_msg =
        WireMsgEncoder.connect_steps(halve_step_id, halve_to_print_proxy_id)
      let finished_msg =
        WireMsgEncoder.initialization_msgs_finished()

      //Leader node (i.e. this one)
      step_manager.add_step(double_step_id, ComputationTypes.double())

      //First worker node
      var conn1 = workers(remote_node_name1)
      conn1.write(halve_create_msg)
      conn1.write(halve_to_print_proxy_create_msg)
      conn1.write(connect_msg)
      conn1.write(finished_msg)

      //Second worker node
      var conn2 = workers(remote_node_name2)
      conn2.write(print_create_msg)
      conn2.write(finished_msg)

      let halve_proxy_id: I32 = 5
      step_manager.add_proxy(halve_proxy_id, halve_step_id, conn1)
      step_manager.connect_steps(1, 5)

      for i in Range(0, 100) do
        let next_msg = Message[I32](i.i32(), i.i32())
        step_manager(1, next_msg)
      end
    else
      @printf[String]("Buffy Leader: Failed to initialize topology".cstring())
    end