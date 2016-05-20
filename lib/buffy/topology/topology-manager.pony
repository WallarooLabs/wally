use "net"
use "collections"
use "buffy/messages"
use "../network"
use "random"

actor TopologyManager
  let _env: Env
  let _auth: AmbientAuth
  let _coordinator: Coordinator
  let _name: String
  let _worker_count: USize
  let _worker_control_addrs: Map[String, (String, String)] = Map[String, (String, String)]
  let _worker_data_addrs: Map[String, (String, String)] = Map[String, (String, String)]
  let _topology: Topology val
  // Keep track of how many workers identified themselves
  var _control_hellos: USize = 0
  var _data_hellos: USize = 0
  var _connection_hellos: USize = 0
  // Keep track of how many workers acknowledged they're running their
  // part of the topology
  var _acks: USize = 0
  let _leader_control_host: String
  let _leader_control_service: String
  let _leader_data_host: String
  let _leader_data_service: String

  new create(env: Env, auth: AmbientAuth, name: String, worker_count: USize,
    leader_control_host: String, leader_control_service: String,
    leader_data_host: String, leader_data_service: String,
    coordinator: Coordinator, topology: Topology val) =>
    _env = env
    _auth = auth
    _coordinator = coordinator
    _name = name
    _worker_count = worker_count
    _topology = topology
    _leader_control_host = leader_control_host
    _leader_control_service = leader_control_service
    _leader_data_host = leader_data_host
    _leader_data_service = leader_data_service

    if _worker_count == 0 then _complete_initialization() end

  be assign_control_conn(node_name: String, control_host: String,
    control_service: String) =>
    _coordinator.establish_control_connection(node_name, control_host, control_service)
    _worker_control_addrs(node_name) = (control_host, control_service)
    _env.out.print("Identified worker " + node_name + " control channel")

  be assign_data_conn(node_name: String, data_host: String,
    data_service: String) =>
    _coordinator.establish_data_connection(node_name, data_host, data_service)
    _worker_data_addrs(node_name) = (data_host, data_service)
    _env.out.print("Identified worker " + node_name + " data channel")

  be ack_control() =>
    if _control_hellos < _worker_count then
      _control_hellos = _control_hellos + 1
      if _control_hellos == _worker_count then
        _env.out.print("_--- All worker control channels accounted for! ---_")
        if (_control_hellos == _worker_count) and (_data_hellos == _worker_count) then
          _coordinator.initialize_topology_connections()
        end
      end
    end

  be ack_data() =>
    if _data_hellos < _worker_count then
      _data_hellos = _data_hellos + 1
      if _data_hellos == _worker_count then
        _env.out.print("_--- All worker data channels accounted for! ---_")
        if (_control_hellos == _worker_count) and (_data_hellos == _worker_count) then
          _coordinator.initialize_topology_connections()
        end
      end
    end

  be ack_finished_connections() =>
    if _connection_hellos < _worker_count then
      _connection_hellos = _connection_hellos + 1
      if _connection_hellos == _worker_count then
        _env.out.print("_--- All worker interconnections complete! ---_")
        _initialize_topology()
      end
    end

  fun ref next_guid(dice: Dice): U64 =>
    dice(1, U64.max_value().u64()).u64()

  // Currently assigns steps in pipeline using round robin among nodes
  fun ref _initialize_topology() =>
    let repeated_steps = Map[U64, U64] // map from pipeline id to step id
    let seed: U64 = 323437823
    let dice = Dice(MT(seed))
    try
      let nodes = Array[String]
      nodes.push(_name)
      let keys = _worker_control_addrs.keys()
      for key in keys do
        nodes.push(key)
      end

      var cur_source_id: U64 = 0
      var cur_sink_id: U64 = 0
      var step_id: U64 = cur_source_id
      var proxy_step_id: U64 = next_guid(dice)
      var proxy_step_target_id: U64 = next_guid(dice)

      for pipeline in _topology.pipelines.values() do
        var count: USize = 0
        // Round robin node assignment
        while count < pipeline.size() do
          let cur_node_idx = count % nodes.size()
          let cur_node = nodes(count % nodes.size())
          let next_node_idx = (cur_node_idx + 1) % nodes.size()
          let next_node = nodes((cur_node_idx + 1) % nodes.size())
          let next_node_control_addr =
            if next_node_idx == 0 then
              (_leader_control_host, _leader_control_service)
            else
              _worker_control_addrs(next_node)
            end
          let next_node_data_addr =
            if next_node_idx == 0 then
              (_leader_data_host, _leader_data_service)
            else
              _worker_data_addrs(next_node)
            end
          let pipeline_step: PipelineStep box = pipeline(count)
          if pipeline_step.id() != 0 then
            try
              step_id = repeated_steps(pipeline_step.id())
            else
              repeated_steps(pipeline_step.id()) = step_id
            end
          end

          if (count + 1) < pipeline.size() then
            let next_pipeline_id = pipeline(count + 1).id()
            if next_pipeline_id != 0 then
              try
                proxy_step_target_id = repeated_steps(next_pipeline_id)
              else
                repeated_steps(next_pipeline_id) = proxy_step_target_id
              end
            end
          end

          _env.out.print("Spinning up computation **** on node \'" + cur_node + "\'")

          if cur_node_idx == 0 then // if cur_node is the leader/source
            _coordinator.add_step(step_id, pipeline_step.step_builder())
            _coordinator.add_proxy(proxy_step_id, proxy_step_target_id, next_node)
            _coordinator.connect_steps(step_id, proxy_step_id)
          else
            let create_step_msg =
              WireMsgEncoder.spin_up(step_id, pipeline_step.step_builder(), _auth)
            let create_proxy_msg =
              WireMsgEncoder.spin_up_proxy(proxy_step_id, proxy_step_target_id,
                next_node, _auth)
            let connect_msg =
              WireMsgEncoder.connect_steps(step_id, proxy_step_id, _auth)

            _coordinator.send_control_message(cur_node, create_step_msg)
            _coordinator.send_control_message(cur_node, create_proxy_msg)
            _coordinator.send_control_message(cur_node, connect_msg)
          end

          count = count + 1
          step_id = proxy_step_target_id
          proxy_step_id = next_guid(dice)
          proxy_step_target_id = next_guid(dice)
        end
        let sink_node_idx = count % nodes.size()
        let sink_node = nodes(sink_node_idx)
        _env.out.print("Spinning up sink on node " + sink_node)

        if sink_node_idx == 0 then // if cur_node is the leader
          _coordinator.add_sink(cur_sink_id, step_id, pipeline.sink_builder(), _auth)
        else
          let create_sink_msg =
            WireMsgEncoder.spin_up_sink(cur_sink_id, step_id,
              pipeline.sink_builder(), _auth)
            _coordinator.send_control_message(sink_node, create_sink_msg)
        end

        cur_source_id = cur_source_id + 1
        cur_sink_id = cur_sink_id + 1
        step_id = cur_source_id
      end

      let finished_msg =
        WireMsgEncoder.initialization_msgs_finished(_name, _auth)
      // Send finished_msg to all workers
      for i in Range(1, nodes.size()) do
        let node = nodes(i)
        _coordinator.send_control_message(node, finished_msg)
      end
    else
      _env.err.print("Buffy Leader: Failed to initialize topology")
    end

  be ack_initialized() =>
    _acks = _acks + 1
    if _acks == _worker_count then
      _complete_initialization()
    end

  fun _complete_initialization() =>
    _env.out.print("_--- Topology successfully initialized ---_")
    let message = ExternalMsgEncoder.topology_ready(_name)
    _coordinator.send_phone_home_message(message)

  be shutdown() =>
    _coordinator.finish_shutdown()
