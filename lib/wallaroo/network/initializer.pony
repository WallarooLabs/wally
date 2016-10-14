use "collections"
use "net"
use "sendence/guid"
use "sendence/messages"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

actor Initializer
  let _guid_gen: GuidGenerator = GuidGenerator
  let _auth: AmbientAuth
  let _expected: USize
  let _connections: Connections
  let _local_topology_initializer: LocalTopologyInitializer
  let _initializer_data_addr: Array[String] val
  let _input_addrs: Array[Array[String]] val
  let _output_addr: Array[String] val
  let _metrics_conn: TCPConnection
  let _ready_workers: Set[String] = Set[String]
  let _is_automated: Bool
  var _topology_starter: (TopologyStarter val | None) = None
  var _topology: (Topology val | None) = None
  var _control_identified: USize = 1
  var _data_identified: USize = 1
  // var interconnected: USize = 0
  var _initialized: USize = 0

  let _worker_names: Array[String] = Array[String]
  let _control_addrs: Map[String, (String, String)] = _control_addrs.create()
  let _data_addrs: Map[String, (String, String)] = _data_addrs.create()

  new create(auth: AmbientAuth, workers: USize, connections: Connections,
    local_topology_initializer: LocalTopologyInitializer,
    input_addrs: Array[Array[String]] val, output_addr: Array[String] val, 
    data_addr: Array[String] val, metrics_conn: TCPConnection,
    is_automated: Bool) 
  =>
    _auth = auth
    _expected = workers
    _connections = connections
    _input_addrs = input_addrs
    _output_addr = output_addr
    _initializer_data_addr = data_addr
    _metrics_conn = metrics_conn
    _local_topology_initializer = local_topology_initializer
    _is_automated = is_automated

  be start(t: (TopologyStarter val | Topology val)) =>
    match t
    | let starter: TopologyStarter val =>
      _topology_starter = starter
    | let topology: Topology val =>
      _topology = topology
    end

  be identify_control_address(worker: String, host: String, service: String) =>
    if _control_addrs.contains(worker) then
      @printf[I32](("Initializer: " + worker + " tried registering control channel twice.\n").cstring())
    else  
      _worker_names.push(worker)
      _control_addrs(worker) = (host, service)
      _control_identified = _control_identified + 1
      if _control_identified == _expected then
        @printf[I32]("All worker control channels identified\n".cstring())

        _initialize()      
      end
    end

  be identify_data_address(worker: String, host: String, service: String) =>
    if _data_addrs.contains(worker) then
      @printf[I32](("Initializer: " + worker + " tried registering data channel twice.\n").cstring())
    else  
      _data_addrs(worker) = (host, service)
      _data_identified = _data_identified + 1
      if _data_identified == _expected then
        @printf[I32]("All worker data channels identified\n".cstring())

        _create_interconnections()
      end
    end

  be distribute_local_topologies(ts: Array[LocalTopology val] val) =>
    if _worker_names.size() != ts.size() then
      @printf[I32]("We need one local topology for each worker\n".cstring())
    else
      for (idx, worker) in _worker_names.pairs() do
        try
          let spin_up_msg = ChannelMsgEncoder.spin_up_local_topology(ts(idx), 
            _auth)
          _connections.send_control(worker, spin_up_msg)
        end
      end
    end

  be topology_ready(worker_name: String) =>
    if not _ready_workers.contains(worker_name) then
      _ready_workers.set(worker_name)
      _initialized = _initialized + 1
      if _initialized == (_expected - 1) then
        let topology_ready_msg = 
          ExternalMsgEncoder.topology_ready("initializer")
        _connections.send_phone_home(topology_ready_msg)
      end
    end

  be register_proxy(worker: String, proxy: Step tag) =>
    _connections.register_proxy(worker, proxy)

  fun ref _initialize() =>
    @printf[I32]("Initializing topology\n".cstring())
    if _is_automated then
      @printf[I32]("Automating...\n".cstring())
      match _topology
      | let t: Topology val =>
        _automate_initialization(t)
      end
    else
      match _topology_starter
      | let t: TopologyStarter val =>
        @printf[I32]("Using user-defined TopologyStarter...\n".cstring())
        try
          t(this, _worker_names, _input_addrs, _expected)
        else
          @printf[I32]("Error running TopologyStarter.\n".cstring())
        end
      else
        @printf[I32]("No topology starter!\n".cstring())
      end
    end

  fun _create_interconnections() =>
    let addresses = _generate_addresses_map()
    try
      let message = ChannelMsgEncoder.create_connections(addresses, _auth)
      for key in _control_addrs.keys() do
        _connections.send_control(key, message)
      end
    else
      @printf[I32]("Initializer: Error initializing interconnections\n".cstring())
    end

  fun _generate_addresses_map(): Map[String, Map[String, (String, String)]] val
  =>
    let map: Map[String, Map[String, (String, String)]] trn = 
      recover Map[String, Map[String, (String, String)]] end
    let control_map: Map[String, (String, String)] trn = 
      recover Map[String, (String, String)] end
    for (key, value) in _control_addrs.pairs() do
      control_map(key) = value
    end
    let data_map: Map[String, (String, String)] trn =
      recover Map[String, (String, String)] end
    for (key, value) in _data_addrs.pairs() do
      data_map(key) = value
    end

    map("control") = consume control_map
    map("data") = consume data_map
    consume map

  fun ref _automate_initialization(topology: Topology val) =>
    try
      // REMOVE LATER (for try block)
      topology.pipelines(0)

      let worker_topology_data = Array[WorkerTopologyData val]

      var pipeline_id: USize = 0

      // Map from step_id to worker name
      let steps: Map[U128, String] = steps.create()
      // Map from worker name to array of local pipelines
      let local_pipelines: Map[String, Array[LocalPipeline val]] =
        local_pipelines.create()

      local_pipelines("initializer") = Array[LocalPipeline val]
      for name in _worker_names.values() do
        local_pipelines(name) = Array[LocalPipeline val]
      end

      for pipeline in topology.pipelines.values() do
        let source_addr_trn: Array[String] trn = recover Array[String] end
        source_addr_trn.push(_input_addrs(0)(0))
        source_addr_trn.push(_input_addrs(0)(1))
        let source_addr: Array[String] val = consume source_addr_trn

        let sink_addr: Array[String] trn = recover Array[String] end
        sink_addr.push(_output_addr(0))
        sink_addr.push(_output_addr(1))

        let sink_egress_builder = EgressBuilder(consume sink_addr, 
          pipeline.sink_runner_builder())

        // Determine which steps go on which workers using boundary indices
        let per_worker: USize = pipeline.size() / _expected
        let boundaries: Array[ISize] = boundaries.create()
        var count: USize = 0
        for i in Range(0, _expected) do
          if (count + per_worker) < pipeline.size() then
            count = count + per_worker
            boundaries.push(count.isize())
          else
            boundaries.push((pipeline.size() - 1).isize())
          end
        end

        var boundaries_idx: USize = 0
        var final_boundary = pipeline.size().isize()
        var last_boundary: ISize = -1
        while boundaries_idx < boundaries.size() do
          let worker = 
            if boundaries_idx == 0 then
              "initializer"
            else
              _worker_names(boundaries_idx - 1)
            end
          let next_worker: (String | None) = 
            try
              _worker_names(boundaries_idx)
            else
              None
            end

          let boundary = boundaries(boundaries_idx)

          let step_builders: Array[StepBuilder val] trn = 
            recover Array[StepBuilder val] end

          if boundary < final_boundary then
            var runner_builders: Array[RunnerBuilder val] trn = 
              recover Array[RunnerBuilder val] end 
            var cur_step_id = _guid_gen.u128()

            for i in Range[ISize](last_boundary + 1, boundary + 1) do
              let next_runner_builder = pipeline(i.usize())
              
              if (next_runner_builder.id() != 0) or 
                  next_runner_builder.is_stateful() then
                if runner_builders.size() > 0 then
                  let seq_builder = RunnerSequenceBuilder(
                    runner_builders = recover Array[RunnerBuilder val] end)
                  let step_builder = StepBuilder(seq_builder, 
                    cur_step_id)
                  step_builders.push(step_builder)
                  steps(cur_step_id) = worker
                end

                let next_seq_builder = RunnerSequenceBuilder(
                  recover [pipeline(i.usize())] end)
                let next_step_builder = StepBuilder(next_seq_builder, 
                  next_runner_builder.id(), next_runner_builder.is_stateful())
                step_builders.push(next_step_builder)
                steps(next_runner_builder.id()) = worker

                cur_step_id = _guid_gen.u128()
              elseif i == boundary then
                let seq_builder = RunnerSequenceBuilder(
                  runner_builders = recover Array[RunnerBuilder val] end)
                let step_builder = StepBuilder(seq_builder, 
                  cur_step_id)
                step_builders.push(step_builder)
                steps(cur_step_id) = worker

                cur_step_id = _guid_gen.u128()
              elseif not pipeline.is_coalesced() then
                let seq_builder = RunnerSequenceBuilder(
                  runner_builders = recover Array[RunnerBuilder val] end)
                let step_builder = StepBuilder(seq_builder, 
                  cur_step_id)
                step_builders.push(step_builder)
                steps(cur_step_id) = worker

                cur_step_id = _guid_gen.u128()                
              else
                runner_builders.push(pipeline(i.usize()))
              end
            end
          end

          try
            let boundary_step_id = step_builders(0).id()      
            let top_data = WorkerTopologyData(worker, boundary_step_id,
              consume step_builders)
            worker_topology_data.push(top_data)
          end

          boundaries_idx = boundaries_idx + 1
        end

        for i in Range(0, worker_topology_data.size()) do
          let cur = worker_topology_data(i)
          let next_worker_data: (WorkerTopologyData val | None) =
            try worker_topology_data(i + 1) else None end

          let source_data = 
            if i == 0 then
              SourceData(pipeline.source_builder(), source_addr)
            else
              None
            end

          match next_worker_data
          | let w: WorkerTopologyData val =>
            // We need a proxy to the next worker
            let proxy_address = ProxyAddress(w.worker_name, w.boundary_step_id)
            let egress_builder = EgressBuilder(proxy_address)
            let local_pipeline = LocalPipeline(pipeline.name(), 
              cur.step_builders, egress_builder, source_data)
            local_pipelines(cur.worker_name).push(local_pipeline)
          else
            // We need a sink
            let egress_builder = EgressBuilder(_output_addr, pipeline_id
              pipeline.sink_runner_builder())
            let local_pipeline = LocalPipeline(pipeline.name(), 
              cur.step_builders, egress_builder, source_data)
            local_pipelines(cur.worker_name).push(local_pipeline)
          end 
        end

        pipeline_id = pipeline_id + 1
      end

      let other_local_topologies: Array[LocalTopology val] trn =
        recover Array[LocalTopology val] end

      // For each worker in local_pipelines, generate a LocalTopology
      for (w, ps) in local_pipelines.pairs() do
        let pvals: Array[LocalPipeline val] trn = 
          recover Array[LocalPipeline val] end
        for p in ps.values() do
          pvals.push(p)
        end
        let local_topology = LocalTopology(topology.name(), consume pvals)

        if w == "initializer" then
          _local_topology_initializer.update_topology(local_topology)
          _local_topology_initializer.initialize() 
        else
          other_local_topologies.push(local_topology)
        end
      end

      distribute_local_topologies(consume other_local_topologies)
    else
      @printf[I32]("Error initializating topology!/n".cstring())
    end


class WorkerTopologyData
  let worker_name: String
  let boundary_step_id: U128
  let step_builders: Array[StepBuilder val] val

  new val create(n: String, id: U128, sb: Array[StepBuilder val] val) =>
    worker_name = n
    boundary_step_id = id
    step_builders = sb

trait TopologyStarter
  fun apply(initializer: Initializer, workers: Array[String] box,
    input_addrs: Array[Array[String]] val, expected: USize) ?
