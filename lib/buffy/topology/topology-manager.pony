use "net"
use "collections"
use "buffy/messages"
use "sendence/guid"
use "../network"
use "random"
use "time"

class SharedStateAddress
  let node_name: String
  let step_id: U64

  new create(n: String, s: U64) =>
    node_name = n
    step_id = s

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

    if _worker_count == 0 then _initialize_topology() end

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

  fun _check_prev(cur: String, prev: (String | None)): Bool =>
    match prev
    | let p: String => cur == p
    else
      false
    end

  // Currently assigns steps in pipeline using round robin among nodes
  fun ref _initialize_topology() =>
    let repeated_steps = Map[U64, U64] // map from pipeline id to step id
    let shared_state_steps = Map[U64, SharedStateAddress] // map from state_id to shared_state_step_id
    let guid_gen = GuidGenerator
    try
      let nodes = Array[String]
      nodes.push(_name)
      let keys = _worker_control_addrs.keys()
      for key in keys do
        nodes.push(key)
      end

      var cur_source_id: U64 = 0
      var step_id: U64 = cur_source_id
      var prev_step_id: (U64 | None) = None
      var prev_node: (String | None) = None
      var proxy_step_id: U64 = guid_gen()
      var proxy_step_target_id: U64 = guid_gen()

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

          _env.out.print("Spinning up computation **** on node '" + cur_node + "'")

          let is_leader = (cur_node_idx == 0)

          match pipeline_step.step_builder()
          | let ssb: BasicStateStepBuilder val =>
            let state_id = ssb.state_id()
            let shared_state_step_addr = try
              shared_state_steps(state_id)
            else
              let ss_id = guid_gen()
              let ss_addr = SharedStateAddress(cur_node, ss_id)
              shared_state_steps(state_id) = ss_addr
              _spin_up_shared_state(ssb.shared_state_step_builder(), ss_id, cur_node,
                is_leader)
              ss_addr
            end

            if is_leader then
              _coordinator.add_state_step(step_id, ssb, shared_state_step_addr.step_id,
                shared_state_step_addr.node_name)
              if (prev_step_id isnt None) and _check_prev(cur_node, prev_node) then
                match prev_step_id
                | let p_id: U64 => _coordinator.connect_steps(p_id, step_id)
                end
              elseif not (cur_node == next_node) then
                _coordinator.add_proxy(proxy_step_id, proxy_step_target_id, next_node)
                _coordinator.connect_steps(step_id, proxy_step_id)
              end
            else
              let create_state_step_msg =
                WireMsgEncoder.spin_up_state_step(step_id, ssb,
                  shared_state_step_addr.step_id, cur_node, _auth)
              let create_proxy_msg =
                WireMsgEncoder.spin_up_proxy(proxy_step_id, proxy_step_target_id,
                  next_node, _auth)
              let connect_msg =
                WireMsgEncoder.connect_steps(step_id, proxy_step_id, _auth)

              _coordinator.send_control_message(cur_node, create_state_step_msg)
              _coordinator.send_control_message(cur_node, create_proxy_msg)
              _coordinator.send_control_message(cur_node, connect_msg)
            end
          else
            if is_leader then
              _coordinator.add_step(step_id, pipeline_step.step_builder())
              if (prev_step_id isnt None) and _check_prev(cur_node, prev_node) then
                match prev_step_id
                | let p_id: U64 => _coordinator.connect_steps(p_id, step_id)
                end
              elseif not (cur_node == next_node) then
                _coordinator.add_proxy(proxy_step_id, proxy_step_target_id, next_node)
                _coordinator.connect_steps(step_id, proxy_step_id)
              end
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
          end

          count = count + 1
          prev_step_id = step_id
          prev_node = cur_node
          step_id = proxy_step_target_id
          proxy_step_id = guid_gen()
          proxy_step_target_id = guid_gen()
        end
        let cur_node = nodes(count % nodes.size())
        let sink_node_idx = count % nodes.size()
        let sink_node = nodes(sink_node_idx)
        _env.out.print("Spinning up sink on node " + sink_node)

        let sendable_sink_ids: Array[U64] iso = recover Array[U64] end
        for id in pipeline.sink_target_ids().values() do
          sendable_sink_ids.push(id)
        end
        if sink_node_idx == 0 then // if cur_node is the leader
          _coordinator.add_sink(consume sendable_sink_ids, step_id,
            pipeline.sink_builder(), _auth)
          if _check_prev(cur_node, prev_node) then
            match prev_step_id
            | let p_id: U64 => _coordinator.connect_steps(p_id, step_id)
            end
          end
        else
          let create_sink_msg =
            WireMsgEncoder.spin_up_sink(consume sendable_sink_ids, step_id,
              pipeline.sink_builder(), _auth)
            _coordinator.send_control_message(sink_node, create_sink_msg)
        end

        cur_source_id = cur_source_id + 1
        step_id = cur_source_id
        prev_step_id = None
        prev_node = None
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

  fun _spin_up_shared_state(shared_state_step_builder: BasicStepBuilder val,
    shared_state_step_id: U64, cur_node: String, is_leader: Bool) =>
    try
      if is_leader then
        _coordinator.add_step(shared_state_step_id, shared_state_step_builder)
      else
        let create_step_msg =
          WireMsgEncoder.spin_up(shared_state_step_id, shared_state_step_builder, _auth)
        _coordinator.send_control_message(cur_node, create_step_msg)
      end
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
