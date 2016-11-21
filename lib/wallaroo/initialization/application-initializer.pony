use "collections"
use "net"
use "sendence/dag"
use "sendence/guid"
use "sendence/messages"
use "wallaroo"
use "wallaroo/backpressure"
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

      // Keep track of shared state so that it's only created once
      let state_partition_map: Map[String, PartitionAddresses val] trn =
        recover Map[String, PartitionAddresses val] end

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

      // Break each pipeline into LocalGraphs to distribute to workers
      for pipeline in application.pipelines.values() do
        if not pipeline.is_coalesced() then
          @printf[I32](("Coalescing is off for " + pipeline.name() + " pipeline\n").cstring())
        end

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

        // If the source contains a prestate runner, then we might need
        // a pre state target id, None if not
        let pre_state_target_id =
          if source_seq_builder.is_prestate() then
            try
              runner_builders(runner_builder_idx + 1).id()
            else
              // We need a sink on every worker involved in the 
              // partition
              let egress_builder = EgressBuilder(pipeline.name(), 
                sink_id, sink_addr, pipeline.sink_builder())

              match partition_workers
              | let w: String =>
                try
                  local_graphs(w).add_node(egress_builder, sink_id)
                else
                  @printf[I32](("No graph for worker " + w + "\n").cstring())
                  error
                end
              | let ws: Array[String] val =>
                local_graphs("initializer").add_node(egress_builder, 
                  sink_id)
                for w in ws.values() do
                  try
                    local_graphs(w).add_node(egress_builder, sink_id)
                  else
                    @printf[I32](("No graph for worker " + w + "\n").cstring())
                    error
                  end
                end
              end

              sink_id
            end
          else
            None
          end

        let source_initializer = SourceData(source_node_id, 
          pipeline.source_builder(), source_seq_builder, 
          pipeline.source_route_builder(), source_addr, pre_state_target_id)

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

        // Each worker gets a boundary value. Let's say initializer gets 2
        // steps, worker2 2 steps, and worker3 3 steps. Then the boundaries
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

          // Set up sink id for this worker for this pipeline (in case there's
          // a sink on it)
          let sink_id = _guid_gen.u128()

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

              //!! TODO: Take what we need from the commented out code below

              // Stateful steps have to be handled differently since pre-state
              // steps must be on the same workers as their corresponding
              // state steps
              // if next_runner_builder.is_stateful() then
              //   // Create the prestate initializer, and if this is not
              //   // partitioned state, then the state initializer as well.
              //   match next_runner_builder
              //   | let pb: PartitionBuilder val =>
              //     @printf[I32](("Preparing to spin up partitioned state on " + worker + "\n").cstring())

              //     // Determine which workers will be involved in this partition
              //     let partition_workers: (String | Array[String] val) = 
              //       if pb.is_multi() then
              //         @printf[I32]("Multiworker Partition\n".cstring())
              //         let w_names: Array[String] trn = 
              //           recover Array[String] end
              //         w_names.push("initializer")
              //         for w in worker_names.values() do
              //           w_names.push(w)
              //         end
              //         consume w_names
              //       else
              //         worker
              //       end

              //     // Handle the shared state
              //     let state_name = pb.state_name()
              //     if not state_partition_map.contains(state_name) then
              //       state_partition_map(state_name) = 
              //         pb.partition_addresses(partition_workers)
              //     end

              //     // Determine whether the state computation target step will 
              //     // be a step or a sink/proxy
                  // let pre_state_target_id =
                  //   try
                  //     runner_builders(runner_builder_idx + 1).id()
                  //   else
                  //     // We need a sink on every worker involved in the 
                  //     // partition
                  //     let egress_builder = EgressBuilder(pipeline.name(), 
                  //       sink_id, sink_addr, pipeline.sink_builder())

                  //     match partition_workers
                  //     | let w: String =>
                  //       try
                  //         local_graphs(w).add_node(egress_builder, sink_id)
                  //       else
                  //         @printf[I32](("No graph for worker " + w + "\n").cstring())
                  //         error
                  //       end
                  //     | let ws: Array[String] val =>
                  //       local_graphs("initializer").add_node(egress_builder, 
                  //         sink_id)
                  //       for w in ws.values() do
                  //         try
                  //           local_graphs(w).add_node(egress_builder, sink_id)
                  //         else
                  //           @printf[I32](("No graph for worker " + w + "\n").cstring())
                  //           error
                  //         end
                  //       end
                  //     end

                  //     sink_id
                  //   end

              //     let next_initializer = PartitionedStateStepBuilder(
              //       application.name(), pipeline.name(),
              //       pb.state_subpartition(partition_workers), 
              //       next_runner_builder, state_name, pre_state_target_id,
              //       next_runner_builder.forward_route_builder(),
              //       pb.default_target_name())
              //     let next_id = next_initializer.id()

              //     try
              //       match partition_workers
              //       | let w: String =>                    
              //         local_graphs(w).add_node(next_initializer, next_id)
              //       | let ws: Array[String] val =>
              //         local_graphs("initializer").add_node(next_initializer, next_id)
              //         for w in ws.values() do
              //           local_graphs(w).add_node(next_initializer, next_id)
              //         end
              //       end

              //       match last_initializer
              //       | (let last_id: U128, let step_init: StepInitializer val) 
              //       =>
              //         local_graphs(worker).add_edge(last_id, next_id)
              //       end
              //     else
              //       @printf[I32](("Possibly no graph for worker " + worker + " when trying to spin up partitioned state\n").cstring())
              //       error
              //     end

              //     last_initializer = None//(next_id, next_initializer) 
              //     steps(next_id) = worker

              //     // TODO: Replace this default strategy with a better one 
              //     // after POC
              //     if pb.default_target_name() != "" then
              //       @printf[I32]("-----We have a real default target name\n".cstring())
              //       match application.default_target
              //       | let default_target: Array[RunnerBuilder val] val =>
              //         @printf[I32](("Preparing to spin up default target state computation for " + next_runner_builder.name() + " on " + worker + "\n").cstring())

              //         // The target will always be the sink (a stipulation of
              //         // the temporary POC strategy)
              //         let default_pre_state_target_id = sink_id

              //         let pre_state_runner_builder = 
              //           try 
              //             default_target(0)
              //           else
              //             @printf[I32]("Default target had no prestate value!\n".cstring())
              //             error
              //           end

              //         let state_runner_builder = 
              //           try 
              //             default_target(1)
              //           else
              //             @printf[I32]("Default target had no state value!\n".cstring())
              //             error
              //           end

              //         let pre_state_id = pre_state_runner_builder.id()
              //         let state_id = state_runner_builder.id()

              //         let pre_state_builder = StepBuilder(application.name(),
              //           pipeline.name(),
              //           pre_state_runner_builder, pre_state_id, 
              //           false, 
              //           default_pre_state_target_id,
              //           pre_state_runner_builder.forward_route_builder())

              //         @printf[I32](("Preparing to spin up default target state for " + state_runner_builder.name() + " on " + worker + "\n").cstring())

              //         let state_builder = StepBuilder(application.name(),
              //           pipeline.name(),
              //           state_runner_builder, state_id,
              //           true 
              //           where forward_route_builder' = 
              //             state_runner_builder.route_builder())
 
              //         // Add prestate to defaults
              //         // Add state to defaults

              //         steps(pre_state_id) = worker
              //         steps(state_id) = worker

              //         let next_default_targets: Array[StepBuilder val] trn = 
              //           recover Array[StepBuilder val] end

              //         next_default_targets.push(pre_state_builder)
              //         next_default_targets.push(state_builder)

              //         @printf[I32](("Adding default target for " + worker + "\n").cstring())
              //         default_targets(worker) = consume next_default_targets

              //         // Create ProxyAddresses for the other workers
              //         let proxy_address = ProxyAddress(worker, 
              //           pre_state_id)

              //         for w in worker_names.values() do
              //           default_targets(w) = proxy_address
              //         end
              //       else
              //         @printf[I32]("----But no default target!\n".cstring())
              //       end
              //     end
              //!!
                // else
                //   @printf[I32](("Preparing to spin up non-partitioned state computation for " + next_runner_builder.name() + " on " + worker + "\n").cstring())
                //   let pre_state_id = next_runner_builder.id()

                //   // Determine whether the target step will be a step or a 
                //   // sink/proxy, hopping forward 2 because the immediate
                //   // successor should be our state step with non-partitioned
                //   // state
                //   let pre_state_target_id =
                //     try
                //       runner_builders(runner_builder_idx + 2).id()
                //     else
                //       sink_id
                //     end

                //   let pre_state_init = StepBuilder(application.name(),
                //     pipeline.name(),
                //     next_runner_builder, pre_state_id, 
                //     next_runner_builder.is_stateful(), pre_state_target_id,
                //     next_runner_builder.forward_route_builder())

                //   try
                //     local_graphs(worker).add_node(pre_state_init, pre_state_id)
                //     match last_initializer
                //     | (let last_id: U128, let step_init: StepInitializer val) 
                //     =>
                //       local_graphs(worker).add_edge(last_id, pre_state_id)
                //     end
                //   else
                //     @printf[I32](("No graph for worker " + worker + "\n").cstring())
                //     error
                //   end
                  
                //   steps(next_runner_builder.id()) = worker

                //   runner_builder_idx = runner_builder_idx + 1

                //   next_runner_builder = 
                //     try
                //       runner_builders(runner_builder_idx)
                //     else
                //       @printf[I32](("No runner builder for idx " + runner_builder_idx.string() + "\n").cstring())
                //       error
                //     end

                //   @printf[I32](("Preparing to spin up non-partitioned state for " + next_runner_builder.name() + " on " + worker + "\n").cstring())

                //   let next_initializer = StepBuilder(application.name(),
                //     pipeline.name(),
                //     next_runner_builder, next_runner_builder.id(),
                //     next_runner_builder.is_stateful())
                //   let next_id = next_initializer.id()

                //   try
                //     local_graphs(worker).add_node(next_initializer, next_id)
                //     local_graphs(worker).add_edge(pre_state_id, next_id)
                //   else
                //     @printf[I32](("No graph for worker " + worker + "\n").cstring())
                //     error
                //   end

                //   last_initializer = None
                //   steps(next_id) = worker
                // end
              if next_runner_builder.is_prestate() then
                // Determine which workers will be involved in this partition
                let partition_workers: (String | Array[String] val) = 
                  if next_runner_builder.is_multi() then
                    @printf[I32]("Multiworker Partition\n".cstring())
                    all_workers
                  else
                    worker
                  end

                let pre_state_target_id =
                  try
                    runner_builders(runner_builder_idx + 1).id()
                  else
                    // We need a sink on every worker involved in the 
                    // partition
                    let egress_builder = EgressBuilder(pipeline.name(), 
                      sink_id, sink_addr, pipeline.sink_builder())

                    match partition_workers
                    | let w: String =>
                      try
                        local_graphs(w).add_node(egress_builder, sink_id)
                      else
                        @printf[I32](("No graph for worker " + w + "\n").cstring())
                        error
                      end
                    | let ws: Array[String] val =>
                      local_graphs("initializer").add_node(egress_builder, 
                        sink_id)
                      for w in ws.values() do
                        try
                          local_graphs(w).add_node(egress_builder, sink_id)
                        else
                          @printf[I32](("No graph for worker " + w + "\n").cstring())
                          error
                        end
                      end
                    end

                    sink_id
                  end
                @printf[I32](("Preparing to spin up " + next_runner_builder.name() + " on " + worker + "\n").cstring())
                let next_id = next_runner_builder.id()
                let next_initializer = StepBuilder(application.name(),
                  pipeline.name(), next_runner_builder, next_id where
                  pre_state_target_id' = pre_state_target_id)
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
                @printf[I32](("Preparing to spin up " + next_runner_builder.name() + " on " + worker + "\n").cstring())
                let next_id = next_runner_builder.id()
                let next_initializer = StepBuilder(application.name(),
                  pipeline.name(), next_runner_builder, next_id)

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
            // We need a Sink since there are no more steps to go in this
            // pipeline
            let egress_builder = EgressBuilder(pipeline.name(), 
              sink_id, sink_addr, pipeline.sink_builder())

            try
              local_graphs(worker).add_node(egress_builder, sink_id)
              match last_initializer
              | (let last_id: U128, let step_init: StepInitializer val) =>
                local_graphs(worker).add_edge(last_id, sink_id)
              end
            else
              @printf[I32](("No graph for worker " + worker + "\n").cstring())
              error
            end
          end

          // Reset the last initializer since we're moving to the next worker
          last_initializer = None
          // Move to next worker's boundary value
          boundaries_idx = boundaries_idx + 1
        end

        // Prepare to initialize the next pipeline
        pipeline_id = pipeline_id + 1
      end

      // Keep track of LocalTopologies that we need to send to other
      // (non-initializer) workers
      let other_local_topologies: Array[LocalTopology val] trn =
        recover Array[LocalTopology val] end

      // For each worker, generate a LocalTopology
      // from all of its LocalGraphs
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
              state_subpartitions, consume p_ids,
              default_target, application.default_target_name,
              application.default_target_id)
          else
            @printf[I32]("Problem cloning graph\n".cstring())
            error
          end

        // If this is the initializer's (i.e. our) turn, then
        // immediately (asynchronously) begin initializing it. If not, add it
        // to the list we'll use to distribute to the other workers
        if w == "initializer" then
          _local_topology_initializer.update_topology(local_topology)
          _local_topology_initializer.initialize(worker_initializer) 
        else
          other_local_topologies.push(local_topology)
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
