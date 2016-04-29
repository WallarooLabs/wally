use "net"
use "options"
use "collections"

actor Startup
  new create(env: Env, topology: Topology val, step_builder: StepBuilder val) =>
    var is_worker = true
    var worker_count: USize = 0
    var node_name: String = "0"
    var phone_home: String = ""
    var options = Options(env)

    options
      .add("leader", "l", None)
      .add("worker_count", "w", I64Argument)
      .add("phone_home", "p", StringArgument)
      .add("name", "n", StringArgument)

    for option in options do
      match option
      | ("leader", None) => is_worker = false
      | ("worker_count", let arg: I64) => worker_count = arg.usize()
      | ("phone_home", let arg: String) => phone_home = arg
      | ("name", let arg: String) => node_name = arg
      end
    end

    var args = options.remaining()

    try
      // Id must be specified and nonzero
      if node_name == "0" then error end

      let leader_addr: Array[String] = args(1).split(":")
      let leader_host = leader_addr(0)
      let leader_service = leader_addr(1)

      let auth = env.root as AmbientAuth
      if is_worker then
        TCPListener(auth,
          WorkerNotifier(env, auth, node_name, leader_host, leader_service, step_builder))
      else
        let notifier = LeaderNotifier(env, auth, node_name, leader_host,
          leader_service, worker_count, phone_home, topology, step_builder)
        TCPListener(auth, consume notifier, leader_host, leader_service)
      end

      if is_worker then
        env.out.print("**Buffy Worker " + node_name + "**")
      else
        env.out.print("**Buffy Leader " + node_name + " at " + leader_host + ":"
          + leader_service + "**")
        env.out.print("** -- Looking for " + worker_count.string()
          + " workers --**")
      end
    else
      TestMain(env)
      env.out.print("Parameters: leader_address [-l -w <worker_count>"
        + "-p <phone_home_address> --id <node_name>]")
    end
