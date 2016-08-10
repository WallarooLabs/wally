use "net"
use "collections"
use "buffy/messages"
use "sendence/messages"
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
  let _nodes: Array[String] = Array[String]
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
  let _source_addrs: Array[String] val
  let _init_data: InitData = InitData
  let _shared_state_steps: Map[U64, SharedStateAddress] 
    = Map[U64, SharedStateAddress] // map from state_id to shared state address

  let _guid_gen: GuidGenerator = GuidGenerator

  new create(env: Env, auth: AmbientAuth, name: String, worker_count: USize,
    leader_control_host: String, leader_control_service: String,
    leader_data_host: String, leader_data_service: String,
    coordinator: Coordinator, topology: Topology val,
    source_addrs: Array[String] val) =>
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
    _source_addrs = source_addrs
    _nodes.push(name)

    if _worker_count == 0 then _initialize_topology(true) end

  be assign_control_conn(node_name: String, control_host: String,
    control_service: String) =>
    _nodes.push(node_name)
    _coordinator.establish_control_connection(node_name, control_host, control_service)
    _env.out.print("Identified worker " + node_name + " control channel")

  be assign_data_conn(node_name: String, data_host: String,
    data_service: String) =>
    _coordinator.establish_data_connection(node_name, data_host, data_service)
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
  fun ref _initialize_topology(single_node: Bool = false) =>
    let repeated_steps = Map[U64, U64] // map from pipeline id to step id
    let guid_gen = GuidGenerator
    try
      for pipeline in _topology.pipelines.values() do
        let source_addr: Array[String] = 
          _source_addrs(_init_data.cur_source_id.usize()).split(":")
        let source_host = source_addr(0)
        let source_service = source_addr(1)
        var local_step_builder: (LocalStepBuilder val | None) = None
        var pipeline_idx: USize = 0

        let cur_node_idx = pipeline_idx % _nodes.size()
        _init_data.set_cur_node(_nodes(pipeline_idx % _nodes.size()))
        let next_node_idx = (cur_node_idx + 1) % _nodes.size()
        _init_data.set_next_node(_nodes((cur_node_idx + 1) % _nodes.size()))

        let initial_step_id = 
          match pipeline(pipeline_idx).step_builder()
          | let local: LocalStepBuilder val =>
            local_step_builder = local
            // If we can build this locally at the source notify,
            // we will.
            match local_step_builder 
            | let ssb: BasicStateStepBuilder val =>
              match ssb.state_id()
              | let state_id: U64 =>
                try
                  _shared_state_steps(state_id)
                else
                  let ss_addr = SharedStateAddress(_init_data.cur_node, 
                    state_id)
                  _shared_state_steps(state_id) = ss_addr
                  _spin_up_shared_state(ssb.shared_state_step_builder(), 
                    state_id, _init_data.cur_node, true)
                end
              end
            end
            pipeline_idx = pipeline_idx + 1
            let step_id = 
              if _init_data.cur_node == _init_data.next_node then
                _init_data.proxy_step_target_id
              else
                _coordinator.add_proxy(_init_data.proxy_step_id, 
                  _init_data.proxy_step_target_id, _init_data.next_node)
                _init_data.proxy_step_id
              end

            _init_data.update_for_next_step()
            step_id
          else
            _init_data.step_id
          end

        // Round robin node assignment
        while pipeline_idx < pipeline.size() do
          _spin_up_step(pipeline_idx, pipeline, repeated_steps)

          pipeline_idx = pipeline_idx + 1
          _init_data.update_for_next_step()
        end

        _init_data.set_cur_node(_nodes(pipeline_idx % _nodes.size()))
        let sink_node_idx = pipeline_idx % _nodes.size()
        let sink_node = _nodes(sink_node_idx)
        _env.out.print("Spinning up sink on node " + sink_node)

        let sendable_sink_ids: Array[U64] iso = recover Array[U64] end
        for id in pipeline.sink_target_ids().values() do
          sendable_sink_ids.push(id)
        end

        if sink_node_idx == 0 then // if cur_node is the leader
          _coordinator.add_sink(consume sendable_sink_ids, _init_data.step_id,
            pipeline.sink_builder(), _auth)
          if _check_prev(_init_data.cur_node, _init_data.prev_node) then
            match _init_data.prev_step_id
            | let p_id: U64 => _coordinator.connect_steps(p_id, 
              _init_data.step_id)
            end
          end
        else
          let create_sink_msg =
            WireMsgEncoder.spin_up_sink(consume sendable_sink_ids, 
              _init_data.step_id,
              pipeline.sink_builder(), _auth)
            _coordinator.send_control_message(sink_node, create_sink_msg)
        end


        _coordinator.initialize_source(_init_data.cur_source_id, pipeline,
          initial_step_id, source_host, source_service, 
          local_step_builder)
        match local_step_builder
        | let l: LocalStepBuilder val =>
          _env.out.print("Initializing source with " 
            + l.name() + " on leader node")
        else
          _env.out.print("Initializing source on leader node")
        end

        _init_data.update_for_next_pipeline()
      end

      let finished_msg =
        WireMsgEncoder.initialization_msgs_finished(_name, _auth)
      // Send finished_msg to all workers
      for i in Range(1, _nodes.size()) do
        let node = _nodes(i)
        _coordinator.send_control_message(node, finished_msg)
      end

      if single_node then _complete_initialization() end
    else
      _env.err.print("Buffy Leader: Failed to initialize topology")
    end

  fun ref _spin_up_step(pipeline_idx: USize, pipeline: PipelineSteps val, 
    repeated_steps: Map[U64, U64]) ? 
  =>
    let cur_node_idx = pipeline_idx % _nodes.size()
    _init_data.set_cur_node(_nodes(pipeline_idx % _nodes.size()))
    let next_node_idx = (cur_node_idx + 1) % _nodes.size()
    _init_data.set_next_node(_nodes((cur_node_idx + 1) % _nodes.size()))
    let pipeline_step: PipelineStep box = pipeline(pipeline_idx)
    if pipeline_step.id() != 0 then
      try
        _init_data.set_step_id(repeated_steps(pipeline_step.id()))
      else
        repeated_steps(pipeline_step.id()) = _init_data.step_id
      end
    end

    if (pipeline_idx + 1) < pipeline.size() then
      let next_pipeline_id = pipeline(pipeline_idx + 1).id()
      if next_pipeline_id != 0 then
        try
          _init_data.set_proxy_step_target_id(repeated_steps(next_pipeline_id))
        else
          repeated_steps(next_pipeline_id) = _init_data.proxy_step_target_id
        end
      end
    end

    _env.out.print("Spinning up computation " + pipeline_step.name() 
      + " on node '" + _init_data.cur_node + "'")

    let is_leader = (cur_node_idx == 0)

    match pipeline_step.step_builder()
    | let ssb: BasicStateStepBuilder val =>
      match ssb.state_id()
      | let state_id: U64 =>
        let shared_state_step_addr = try
          _shared_state_steps(state_id)
        else
          let ss_addr = SharedStateAddress(_init_data.cur_node, state_id)
          _shared_state_steps(state_id) = ss_addr
          _spin_up_shared_state(ssb.shared_state_step_builder(), state_id, 
            _init_data.cur_node, is_leader)
          ss_addr
        end
        _spin_up_state_step(is_leader, ssb, shared_state_step_addr)
      else
        _spin_up_nonstate_step(is_leader, pipeline_step)
      end
    else
      _spin_up_nonstate_step(is_leader, pipeline_step)
    end

  fun _spin_up_nonstate_step(is_leader: Bool, 
    pipeline_step: PipelineStep box) ?
  =>
    if is_leader then
      _coordinator.add_step(_init_data.step_id, pipeline_step.step_builder())
      if (_init_data.prev_step_id isnt None) and 
        _check_prev(_init_data.cur_node, _init_data.prev_node) then
        match _init_data.prev_step_id
        | let p_id: U64 => _coordinator.connect_steps(p_id, 
          _init_data.step_id)
        end
      elseif not (_init_data.cur_node == _init_data.next_node) then
        _coordinator.add_proxy(_init_data.proxy_step_id, 
          _init_data.proxy_step_target_id, _init_data.next_node)
        _coordinator.connect_steps(_init_data.step_id, 
          _init_data.proxy_step_id)
      end
    else
      let create_step_msg =
        WireMsgEncoder.spin_up(_init_data.step_id, 
          pipeline_step.step_builder(), _auth)
      let create_proxy_msg =
        WireMsgEncoder.spin_up_proxy(_init_data.proxy_step_id, 
          _init_data.proxy_step_target_id,
          _init_data.next_node, _auth)
      let connect_msg =
        WireMsgEncoder.connect_steps(_init_data.step_id, 
          _init_data.proxy_step_id, _auth)

      _coordinator.send_control_message(_init_data.cur_node, create_step_msg)
      _coordinator.send_control_message(_init_data.cur_node, 
        create_proxy_msg)
      _coordinator.send_control_message(_init_data.cur_node, connect_msg)
    end 

  fun _spin_up_shared_state(
    shared_state_step_builder: BasicSharedStateStepBuilder val,
    shared_state_step_id: U64, cur_node: String, is_leader: Bool)
  =>
    try
      if is_leader then
        _coordinator.add_shared_state_step(shared_state_step_id, 
          shared_state_step_builder)
      else
        let create_step_msg =
          WireMsgEncoder.spin_up_shared_state(shared_state_step_id, 
            shared_state_step_builder, _auth)
        _coordinator.send_control_message(cur_node, create_step_msg)
      end
    end

  fun _spin_up_state_step(is_leader: Bool, ssb: BasicStateStepBuilder val, 
    shared_state_step_addr: SharedStateAddress) ?
  =>
    if is_leader then
      _coordinator.add_state_step(_init_data.step_id, ssb,
        shared_state_step_addr.step_id, shared_state_step_addr.node_name)
      if (_init_data.prev_step_id isnt None) and 
        _check_prev(_init_data.cur_node, _init_data.prev_node) then
        match _init_data.prev_step_id
        | let p_id: U64 => _coordinator.connect_steps(p_id, 
          _init_data.step_id)
        end
      elseif not (_init_data.cur_node == _init_data.next_node) then
        _coordinator.add_proxy(_init_data.proxy_step_id, 
          _init_data.proxy_step_target_id, _init_data.next_node)
        _coordinator.connect_steps(_init_data.step_id, 
          _init_data.proxy_step_id)
      end
    else
      let create_state_step_msg =
        WireMsgEncoder.spin_up_state_step(_init_data.step_id, ssb,
          shared_state_step_addr.step_id, _init_data.cur_node, _auth)
      let create_proxy_msg =
        WireMsgEncoder.spin_up_proxy(_init_data.proxy_step_id, 
          _init_data.proxy_step_target_id, _init_data.next_node, _auth)
      let connect_msg =
        WireMsgEncoder.connect_steps(_init_data.step_id, 
          _init_data.proxy_step_id, _auth)

      _coordinator.send_control_message(
        _init_data.cur_node, create_state_step_msg)
      _coordinator.send_control_message(_init_data.cur_node, 
        create_proxy_msg)
      _coordinator.send_control_message(_init_data.cur_node, connect_msg)
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

class InitData          
  let guid_gen: GuidGenerator = GuidGenerator
  var cur_source_id: U64 = 0
  var cur_node: String = ""
  var next_node: String = ""
  var step_id: U64 = cur_source_id
  var prev_step_id: (U64 | None) = None
  var prev_node: (String | None) = None
  var proxy_step_id: U64 = guid_gen()
  var proxy_step_target_id: U64 = guid_gen()

  fun ref set_cur_source_id(d: U64) =>
    cur_source_id = d

  fun ref set_cur_node(d: String) =>
    cur_node = d

  fun ref set_next_node(d: String) =>
    next_node = d

  fun ref set_step_id(d: U64) =>
    step_id = d
  
  fun ref set_prev_step_id(d: (U64 | None)) =>
    prev_step_id = d

  fun ref set_prev_node(d: (String | None)) =>
    prev_node = d

  fun ref set_proxy_step_id(d: U64) =>
    proxy_step_id = d

  fun ref set_proxy_step_target_id(d: U64) =>
    proxy_step_target_id = d

  fun ref update_for_next_pipeline() =>
    cur_source_id = cur_source_id + 1
    step_id = cur_source_id
    prev_step_id = None
    prev_node = None

  fun ref update_for_next_step() =>
    prev_node = cur_node
    prev_step_id = step_id
    step_id = proxy_step_target_id
    proxy_step_id = guid_gen()
    proxy_step_target_id = guid_gen()
