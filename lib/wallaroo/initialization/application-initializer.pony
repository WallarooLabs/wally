use "collections"
use "net"
use "sendence/dag"
use "sendence/guid"
use "sendence/messages"
use "wallaroo"
use "wallaroo/backpressure"
use "wallaroo/fail"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"
use "wallaroo/resilience"

actor ApplicationInitializer
  let _auth: AmbientAuth
  let _guid_gen: GuidGenerator = GuidGenerator
  let _local_topology_initializer: LocalTopologyInitializer
  let _input_addrs: Array[Array[String]] val
  let _output_addr: Array[String] val
  let _alfred: Alfred tag

  var _application: (Application val | None) = None

  new create(auth: AmbientAuth,
    local_topology_initializer: LocalTopologyInitializer,
    input_addrs: Array[Array[String]] val,
    output_addr: Array[String] val, alfred: Alfred tag)
  =>
    _auth = auth
    _local_topology_initializer = local_topology_initializer
    _input_addrs = input_addrs
    _output_addr = output_addr
    _alfred = alfred

  be update_application(app: Application val) =>
    _application = app

  be initialize(worker_initializer: WorkerInitializer, worker_count: USize,
    worker_names: Array[String] val)
  =>
    match _application
    | let a: Application val =>
      @printf[I32]("Initializing application\n".cstring())
      _automate_initialization(a, worker_initializer, worker_count,
        worker_names, _alfred)
    else
      @printf[I32]("No application provided!\n".cstring())
    end

  be topology_ready() =>
    @printf[I32]("Application has successfully initialized.\n".cstring())

    match _application
    | let app: Application val =>
      for i in Range(0, _input_addrs.size()) do
        try
          let init_file = app.init_files(i)
          let file = InitFileReader(init_file, _auth)
          file.read_into(_input_addrs(i))
        end
      end
    end

  fun ref _automate_initialization(application: Application val,
    worker_initializer: WorkerInitializer, worker_count: USize,
    worker_names: Array[String] val, alfred: Alfred tag)
  =>
    @printf[I32]("---------------------------------------------------------\n".cstring())
    @printf[I32]("^^^^^^Initializing Topologies for Workers^^^^^^^\n\n".cstring())
    try
      let all_workers_trn: Array[String] trn = recover Array[String] end
      all_workers_trn.push("initializer")
      for w in worker_names.values() do all_workers_trn.push(w) end
      let all_workers: Array[String] val = consume all_workers_trn

      // Keep track of all steps in the cluster and their proxy addresses.
      // This includes sinks but not sources, since we never send a message
      // directly to a source. For a sink, we don't keep a proxy address but
      // a step id (U128), since every worker will have its own instance of
      // that sink.
      let step_map: Map[U128, (ProxyAddress val | U128)] trn =
        recover Map[U128, (ProxyAddress val | U128)] end

      // Keep track of shared state so that it's only created once
      let state_partition_map: Map[String, PartitionAddresses val] trn =
        recover Map[String, PartitionAddresses val] end

      // Keep track of all prestate data so we can register routes
      let pre_state_data: Array[PreStateData val] trn =
        recover Array[PreStateData val] end

      // This will be incremented as we move through pipelines
      var pipeline_id: USize = 0

      // Map from step_id to worker name
      let steps: Map[U128, String] = steps.create()

      // TODO: Replace this when POC default target strategy is updated
      // Map from worker name to default target
      let default_targets:
        Map[String, (Array[StepBuilder val] val | ProxyAddress val)]
          = default_targets.create()

      // We use these graphs to build the local graphs for each worker
      let local_graphs: Map[String, Dag[StepInitializer val] trn] trn =
        recover Map[String, Dag[StepInitializer val] trn] end

      // Initialize values for local graphs
      local_graphs("initializer") = Dag[StepInitializer val]
      for name in worker_names.values() do
        local_graphs(name) = Dag[StepInitializer val]
      end

      // Create StateSubpartitions
      let ssb_trn: Map[String, StateSubpartition val] trn =
        recover Map[String, StateSubpartition val] end
      for (s_name, p_builder) in application.state_builders().pairs() do
        ssb_trn(s_name) = p_builder.state_subpartition(all_workers)
      end
      let state_subpartitions: Map[String, StateSubpartition val] val =
        consume ssb_trn

      // Keep track of proxy ids per worker
      let proxy_ids: Map[String, Map[String, U128]] = proxy_ids.create()


      @printf[I32](("Found " + application.pipelines.size().string()  + " pipelines in application\n").cstring())

      // Add stepbuilders for each pipeline into LocalGraphs to distribute to // workers
      for pipeline in application.pipelines.values() do
        if not pipeline.is_coalesced() then
          @printf[I32](("Coalescing is off for " + pipeline.name() + " pipeline\n").cstring())
        end

        // Since every worker will have an instance of the sink, we record
        // the step id and not the proxy address in our step map if there
        // is a step id for this pipeline.
        match pipeline.sink_id()
        | let sid: U128 =>
          step_map(sid) = sid
        end

        // TODO: Replace this when we have a better post-POC default strategy.
        // This is set if we need a default target in this pipeline.
        // Currently there can only be one default target per topology.
        var pipeline_default_state_name = ""
        var pipeline_default_target_worker = ""

        let source_addr_trn: Array[String] trn = recover Array[String] end
        try
          source_addr_trn.push(_input_addrs(pipeline_id)(0))
          source_addr_trn.push(_input_addrs(pipeline_id)(1))
        else
          @printf[I32]("No input address!\n".cstring())
          error
        end
        let source_addr: Array[String] val = consume source_addr_trn

        let sink_addr_trn: Array[String] trn = recover Array[String] end
        try
          sink_addr_trn.push(_output_addr(0))
          sink_addr_trn.push(_output_addr(1))
        else
          @printf[I32]("No output address!\n".cstring())
          error
        end
        let sink_addr: Array[String] val = consume sink_addr_trn

        @printf[I32](("The " + pipeline.name() + " pipeline has " + pipeline.size().string() + " uncoalesced runner builders\n").cstring())


        //////////
        // Coalesce runner builders if we can
        var handled_source_runners = false
        var source_runner_builders: Array[RunnerBuilder val] trn =
          recover Array[RunnerBuilder val] end

        // We'll use this array when creating StepInitializers
        let runner_builders: Array[RunnerBuilder val] trn =
          recover Array[RunnerBuilder val] end

        var latest_runner_builders: Array[RunnerBuilder val] trn =
          recover Array[RunnerBuilder val] end

        for i in Range(0, pipeline.size()) do
          let r_builder =
            try
              pipeline(i)
            else
              @printf[I32](" couldn't find pipeline for index\n".cstring())
              error
            end
          if r_builder.is_stateful() then
            if handled_source_runners then
              latest_runner_builders.push(r_builder)
              let seq_builder = RunnerSequenceBuilder(
                latest_runner_builders = recover Array[RunnerBuilder val] end
                )
              runner_builders.push(seq_builder)
            else
              source_runner_builders.push(r_builder)
              handled_source_runners = true
            end
          elseif not pipeline.is_coalesced() then
            if handled_source_runners then
              runner_builders.push(r_builder)
            else
              source_runner_builders.push(r_builder)
              handled_source_runners = true
            end
          // TODO: If the developer specified an id, then this needs to be on
          // a separate step to be accessed by multiple pipelines
          // elseif ??? then
          //   runner_builders.push(r_builder)
          //   handled_source_runners = true
          else
            if handled_source_runners then
              latest_runner_builders.push(r_builder)
            else
              source_runner_builders.push(r_builder)
            end
          end
        end

        if latest_runner_builders.size() > 0 then
          let seq_builder = RunnerSequenceBuilder(
            latest_runner_builders = recover Array[RunnerBuilder val] end)
          runner_builders.push(seq_builder)
        end

        // Create Source Initializer and add it to the graph for the
        // initializer worker.
        let source_node_id = _guid_gen.u128()
        let source_seq_builder = RunnerSequenceBuilder(
            source_runner_builders = recover Array[RunnerBuilder val] end)

        let source_partition_workers: (String | Array[String] val | None) =
          if source_seq_builder.is_prestate() then
            if source_seq_builder.is_multi() then
              @printf[I32]("Multiworker Partition\n".cstring())
              all_workers
            else
              "initializer"
            end
          else
            None
          end

        // If the source contains a prestate runner, then we might need
        // a pre state target id, None if not
        let source_pre_state_target_id: (U128 | None) =
          if source_seq_builder.is_prestate() then
            try
              runner_builders(0).id()
            else
              match pipeline.sink_id()
              | let sid: U128 =>
                // We need a sink on every worker involved in the
                // partition
                let egress_builder = EgressBuilder(pipeline.name(),
                  sid, sink_addr, pipeline.sink_builder())

                match source_partition_workers
                | let w: String =>
                  try
                    local_graphs(w).add_node(egress_builder, sid)
                  else
                    @printf[I32](("No graph for worker " + w + "\n").cstring())
                    error
                  end
                | let ws: Array[String] val =>
                  local_graphs("initializer").add_node(egress_builder,
                    sid)
                  for w in ws.values() do
                    try
                      local_graphs(w).add_node(egress_builder, sid)
                    else
                      @printf[I32](("No graph for worker " + w + "\n").cstring())
                      error
                    end
                  end
                // source_partition_workers shouldn't be None since we showed
                // that source_seq_builders.is_prestate() is true
                end
              end

              pipeline.sink_id()
            end
          else
            None
          end

        if source_seq_builder.is_prestate() then
          let psd = PreStateData(source_seq_builder,
            source_pre_state_target_id)
          pre_state_data.push(psd)

          let state_builder =
            try
              application.state_builder(psd.state_name())
            else
              @printf[I32]("Failed to find state builder for prestate.\n".cstring())
              error
            end
          if state_builder.default_state_name() != "" then
            pipeline_default_state_name = state_builder.default_state_name()
            pipeline_default_target_worker = "initializer"
          end
        end

        let source_initializer = SourceData(source_node_id,
          pipeline.source_builder(), source_seq_builder,
          pipeline.source_route_builder(), source_addr,
          source_pre_state_target_id)

        @printf[I32](("\nPreparing to spin up " + source_seq_builder.name() + " on source on initializer\n").cstring())

        try
          local_graphs("initializer").add_node(source_initializer,
            source_node_id)
        else
          @printf[I32]("problem adding node to initializer graph\n".cstring())
          error
        end

        // The last (node_id, StepInitializer val) pair we created.
        // Gets set to None when we cross to the next worker since it
        // doesn't need to know its immediate cross-worker predecessor.
        // If the source has a prestate runner on it, then we set this
        // to None since it won't send directly to anything.
        var last_initializer: ((U128, StepInitializer val) | None) =
          if source_seq_builder.state_name() == "" then
            (source_node_id, source_initializer)
          else
            None
          end


        // Determine which steps go on which workers using boundary indices
        // Each worker gets a near-equal share of the total computations
        // in this naive algorithm
        let per_worker: USize =
          if runner_builders.size() <= worker_count then
            1
          else
            runner_builders.size() / worker_count
          end

        @printf[I32](("Each worker gets roughly " + per_worker.string() + " steps\n").cstring())

        // Each worker gets a boundary value. Let's say "initializer" gets 2
        // steps, "worker2" 2 steps, and "worker3" 3 steps. Then the boundaries
        // array will look like: [2, 4, 7]
        let boundaries: Array[USize] = boundaries.create()
        // Since we put the source on the first worker, start at -1 to
        // indicate that it gets one less step than everyone else (all things
        // being equal). per_worker must be at least 1, so the first worker's
        // boundary will be at least 0.
        var count: USize = 0
        for i in Range(0, worker_count) do
          count = count + per_worker

          // We don't want to cross a boundary to get to the worker
          // that is the "anchor" for the partition, so instead we
          // make sure it gets put on the same worker
          try
            match runner_builders(count)
            | let pb: PartitionBuilder val =>
              count = count + 1
            end
          end

          if (i == (worker_count - 1)) and
            (count < runner_builders.size()) then
            // Make sure we cover all steps by forcing the rest on the
            // last worker if need be
            boundaries.push(runner_builders.size())
          else
            let b = if count < runner_builders.size() then
              count
            else
              runner_builders.size()
            end
            boundaries.push(b)
          end
        end

        // Keep track of which runner_builder we're on in this pipeline
        var runner_builder_idx: USize = 0
        // Keep track of which worker's boundary we're using
        var boundaries_idx: USize = 0

        ///////////
        // WORKERS

        // For each worker, use its boundary value to determine which
        // runner_builders to use to create StepInitializers that will be
        // added to its local graph
        while boundaries_idx < boundaries.size() do
          let boundary =
            try
              boundaries(boundaries_idx)
            else
              @printf[I32](("No boundary found for boundaries_idx " + boundaries_idx.string() + "\n").cstring())
              error
            end

          let worker =
            if boundaries_idx == 0 then
              "initializer"
            else
              try
                worker_names(boundaries_idx - 1)
              else
                @printf[I32]("No worker found for idx!\n".cstring())
                error
              end
            end
          // Keep track of which worker follows this one in order
          let next_worker: (String | None) =
            try
              worker_names(boundaries_idx)
            else
              None
            end

          let local_proxy_ids = Map[String, U128]
          proxy_ids(worker) = local_proxy_ids
          if worker != "initializer" then
            local_proxy_ids("initializer") = _guid_gen.u128()
          end
          for w in worker_names.values() do
            if worker != w then
              local_proxy_ids(w) = _guid_gen.u128()
            end
          end

          // Make sure there are still runner_builders left in the pipeline.
          if runner_builder_idx < runner_builders.size() then
            var cur_step_id = _guid_gen.u128()

            // Until we hit the boundary for this worker, keep adding
            // stepinitializers from the pipeline
            while runner_builder_idx < boundary do
              var next_runner_builder: RunnerBuilder val =
                try
                  runner_builders(runner_builder_idx)
                else
                  @printf[I32](("No runner builder found for idx " + runner_builder_idx.string() + "\n").cstring())
                  error
                end

              if next_runner_builder.is_prestate() then
              //////////////////////////
              // PRESTATE RUNNER BUILDER
                // Determine which workers will be involved in this partition
                let partition_workers: (String | Array[String] val) =
                  if next_runner_builder.is_multi() then
                    @printf[I32]("Multiworker Partition\n".cstring())
                    all_workers
                  else
                    worker
                  end

                let pre_state_target_id: (U128 | None) =
                  try
                    runner_builders(runner_builder_idx + 1).id()
                  else
                    match pipeline.sink_id()
                    | let sid: U128 =>
                      // We need a sink on every worker involved in the
                      // partition
                      let egress_builder = EgressBuilder(pipeline.name(),
                        sid, sink_addr, pipeline.sink_builder())

                      match partition_workers
                      | let w: String =>
                        try
                          local_graphs(w).add_node(egress_builder, sid)
                        else
                          @printf[I32](("No graph for worker " + w + "\n").cstring())
                          error
                        end
                      | let ws: Array[String] val =>
                        local_graphs("initializer").add_node(egress_builder,
                          sid)
                        for w in ws.values() do
                          try
                            local_graphs(w).add_node(egress_builder, sid)
                          else
                            @printf[I32](("No graph for worker " + w + "\n").cstring())
                            error
                          end
                        end
                      end
                    end

                    pipeline.sink_id()
                  end

                @printf[I32](("Preparing to spin up prestate step " + next_runner_builder.name() + " on " + worker + "\n").cstring())

                let psd = PreStateData(next_runner_builder,
                  pre_state_target_id)
                pre_state_data.push(psd)

                let state_builder =
                  try
                    application.state_builder(psd.state_name())
                  else
                    @printf[I32]("Failed to find state builder for prestate.\n".cstring())
                    error
                  end

                // TODO: Update this approach when we create post-POC default
                // strategy.
                // ASSUMPTION: There is only one partititon default target
                // per application.
                if state_builder.default_state_name() != "" then
                  pipeline_default_state_name =
                    state_builder.default_state_name()
                  pipeline_default_target_worker = "worker"
                end

                let next_id = next_runner_builder.id()
                let next_initializer = StepBuilder(application.name(),
                  pipeline.name(), next_runner_builder, next_id where
                  pre_state_target_id' = pre_state_target_id)
                step_map(next_id) = ProxyAddress(worker, next_id)
                try
                  local_graphs(worker).add_node(next_initializer, next_id)
                  match last_initializer
                  | (let last_id: U128, let step_init: StepInitializer val) =>
                    local_graphs(worker).add_edge(last_id, next_id)
                  end

                  // Pre state step uses a partition router and has no direct
                  // out, so don't connect an edge to the next node
                  last_initializer = None
                else
                  @printf[I32](("No graph for worker " + worker + "\n").cstring())
                  error
                end

                steps(next_id) = worker
              else
              //////////////////////////////
              // NON-PRESTATE RUNNER BUILDER
                @printf[I32](("Preparing to spin up " + next_runner_builder.name() + " on " + worker + "\n").cstring())
                let next_id = next_runner_builder.id()
                let next_initializer = StepBuilder(application.name(),
                  pipeline.name(), next_runner_builder, next_id)
                step_map(next_id) = ProxyAddress(worker, next_id)

                try
                  local_graphs(worker).add_node(next_initializer, next_id)
                  match last_initializer
                  | (let last_id: U128, let step_init: StepInitializer val) =>
                    local_graphs(worker).add_edge(last_id, next_id)
                  end

                  last_initializer = (next_id, next_initializer)
                else
                  @printf[I32](("No graph for worker " + worker + "\n").cstring())
                  error
                end

                steps(next_id) = worker
              end

              runner_builder_idx = runner_builder_idx + 1
            end
            // We've reached the end of this worker's runner builders for this // pipeline
          end

          // Create the EgressBuilder for this worker and add to its graph.
          // First, check if there is going to be a step across the boundary
          if runner_builder_idx < runner_builders.size() then
          ///////
          // We need a Proxy since there are more steps to go in this
          // pipeline
            match next_worker
            | let w: String =>
              let next_runner_builder =
                try
                  runner_builders(runner_builder_idx)
                else
                  @printf[I32](("No runner builder found for idx " + runner_builder_idx.string() + "\n").cstring())
                  error
                end

              match next_runner_builder
              | let pb: PartitionBuilder val =>
                @printf[I32]("A PartitionBuilder should never begin the chain on a non-initializer worker!\n".cstring())
                error
              else
                // Build our egress builder for the proxy
                let egress_id =
                  try
                    runner_builders(runner_builder_idx).id()
                  else
                    @printf[I32](("No runner builder found for idx " + runner_builder_idx.string() + "\n").cstring())
                    error
                  end

                let proxy_address = ProxyAddress(w, egress_id)

                let egress_builder = EgressBuilder(pipeline.name(),
                  egress_id, proxy_address)

                try
                  // If we've already created a node for this proxy, it
                  // will simply be overwritten (which effectively means
                  // there is one node per OutgoingBoundary)
                  local_graphs(worker).add_node(egress_builder, egress_id)
                  match last_initializer
                  | (let last_id: U128, let step_init: StepInitializer val) =>
                    local_graphs(worker).add_edge(last_id, egress_id)
                  end
                else
                  @printf[I32](("No graph for worker " + worker + "\n").cstring())
                  error
                end
              end
            else
              // Something went wrong, since if there are more runner builders
              // there should be more workers
              @printf[I32]("Not all runner builders were assigned to a worker\n".cstring())
              error
            end
          else
          ///////
          // There are no more steps to go in this pipeline, so check if
          // we need a sink
            match pipeline.sink_id()
            | let sid: U128 =>
              let egress_builder = EgressBuilder(pipeline.name(),
                sid, sink_addr, pipeline.sink_builder())

              try
                local_graphs(worker).add_node(egress_builder, sid)
                match last_initializer
                | (let last_id: U128, let step_init: StepInitializer val) =>
                  local_graphs(worker).add_edge(last_id, sid)
                end
              else
                @printf[I32](("No graph for worker " + worker + "\n").cstring())
                error
              end
            end
          end

          // Reset the last initializer since we're moving to the next worker
          last_initializer = None
          // Move to next worker's boundary value
          boundaries_idx = boundaries_idx + 1
          // Finished with this worker for this pipeline
        end

        ////////////////////////////////////////////////////////////////
        // HANDLE PARTITION DEFAULT STEP IF ONE EXISTS FOR THIS PIPELINE
        ////////
        // TODO: Replace this default strategy with a better one
        // after POC
        if pipeline_default_state_name != "" then
          @printf[I32]("-----We have a real default target name\n".cstring())
          match application.default_target
          | let default_target: Array[RunnerBuilder val] val =>
            @printf[I32](("Preparing to spin up default target state on " + pipeline_default_target_worker + "\n").cstring())

            // The target will always be the sink (a stipulation of
            // the temporary POC strategy)
            match pipeline.sink_id()
            | let default_pre_state_target_id: U128 =>
              let pre_state_runner_builder =
                try
                  default_target(0)
                else
                  @printf[I32]("Default target had no prestate value!\n".cstring())
                  error
                end

              let state_runner_builder =
                try
                  default_target(1)
                else
                  @printf[I32]("Default target had no state value!\n".cstring())
                  error
                end

              let pre_state_id = pre_state_runner_builder.id()
              let state_id = state_runner_builder.id()

              // Add default prestate to PreStateData
              let psd = PreStateData(pre_state_runner_builder,
                default_pre_state_target_id, true)
              pre_state_data.push(psd)

              let pre_state_builder = StepBuilder(application.name(),
                pipeline.name(),
                pre_state_runner_builder, pre_state_id,
                false,
                default_pre_state_target_id,
                pre_state_runner_builder.forward_route_builder())

              @printf[I32](("Preparing to spin up default target state for " + state_runner_builder.name() + " on " + pipeline_default_target_worker + "\n").cstring())

              let state_builder = StepBuilder(application.name(),
                pipeline.name(),
                state_runner_builder, state_id,
                true
                where forward_route_builder' =
                  state_runner_builder.route_builder())

              steps(pre_state_id) = pipeline_default_target_worker
              steps(state_id) = pipeline_default_target_worker

              let next_default_targets: Array[StepBuilder val] trn =
                recover Array[StepBuilder val] end

              next_default_targets.push(pre_state_builder)
              next_default_targets.push(state_builder)

              @printf[I32](("Adding default target for " + pipeline_default_target_worker + "\n").cstring())
              default_targets(pipeline_default_target_worker) = consume next_default_targets

              // Create ProxyAddresses for the other workers
              let proxy_address = ProxyAddress(pipeline_default_target_worker,
                pre_state_id)

              for w in worker_names.values() do
                default_targets(w) = proxy_address
              end
            else
              // We currently assume that a default step will target a sink
              // but apparently there is no sink for this pipeline
              Fail()
            end
          else
            @printf[I32]("----But no default target!\n".cstring())
          end
        end

        // Prepare to initialize the next pipeline
        pipeline_id = pipeline_id + 1
      end

      let sendable_step_map: Map[U128, (ProxyAddress val | U128)] val =
        consume step_map

      let sendable_pre_state_data: Array[PreStateData val] val =
        consume pre_state_data

      // Keep track of LocalTopologies that we need to send to other
      // (non-"initializer") workers
      let other_local_topologies: Map[String, LocalTopology val] trn =
        recover Map[String, LocalTopology val] end

      // For each worker, generate a LocalTopology from its LocalGraph
      for (w, g) in local_graphs.pairs() do
        let p_ids: Map[String, U128] trn = recover Map[String, U128] end
        for (target, p_id) in proxy_ids(w).pairs() do
          p_ids(target) = p_id
        end

        let default_target =
          try
            default_targets(w)
          else
            @printf[I32](("No default target specified for " + w + "\n").cstring())
            None
          end

        let local_topology =
          try
            LocalTopology(application.name(), w, g.clone(),
              sendable_step_map, state_subpartitions, sendable_pre_state_data,
              consume p_ids, default_target, application.default_state_name,
              application.default_target_id)
          else
            @printf[I32]("Problem cloning graph\n".cstring())
            error
          end

        // If this is the "initializer"'s (i.e. our) turn, then
        // immediately (asynchronously) begin initializing it. If not, add it
        // to the list we'll use to distribute to the other workers
        if w == "initializer" then
          _local_topology_initializer.update_topology(local_topology)
          _local_topology_initializer.initialize(worker_initializer)
        else
          other_local_topologies(w) = local_topology
        end
      end

      // Distribute the LocalTopologies to the other (non-initializer) workers
      match worker_initializer
      | let wi: WorkerInitializer =>
        wi.distribute_local_topologies(consume other_local_topologies)
      else
        @printf[I32]("Error distributing local topologies!\n".cstring())
      end

      @printf[I32]("\n^^^^^^Finished Initializing Topologies for Workers^^^^^^^\n".cstring())
      @printf[I32]("---------------------------------------------------------\n".cstring())
    else
      @printf[I32]("Error initializating application!\n".cstring())
    end
