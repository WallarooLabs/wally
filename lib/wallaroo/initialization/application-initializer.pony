use "collections"
use "net"
use "sendence/guid"
use "sendence/messages"
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
          let filename = app.init_files(i)
          let file = InitFile(filename, _auth)
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
      // Keep track of shared state so that it's only created once
      let state_partition_map: Map[String, PartitionAddresses val] trn =
        recover Map[String, PartitionAddresses val] end

      // The worker-specific summaries
      var worker_topology_data = Array[WorkerTopologyData val]

      var pipeline_id: USize = 0

      // Map from step_id to worker name
      let steps: Map[U128, String] = steps.create()
      // Map from worker name to array of local pipelines
      let local_pipelines: Map[String, Array[LocalPipeline val]] =
        local_pipelines.create()

      // Initialize values for local pipelines
      local_pipelines("initializer") = Array[LocalPipeline val]
      for name in worker_names.values() do
        local_pipelines(name) = Array[LocalPipeline val]
      end

      @printf[I32](("Found " + application.pipelines.size().string()  + " pipelines in application\n").cstring())

      // Break each pipeline into LocalPipelines to distribute to workers
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

        let sink_addr: Array[String] trn = recover Array[String] end
        try
          sink_addr.push(_output_addr(0))
          sink_addr.push(_output_addr(1))
        else
          @printf[I32]("No output address!\n".cstring())
          error
        end

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
          let r_builder = pipeline(i)
          if r_builder.is_stateful() then
            if latest_runner_builders.size() > 0 then
              let seq_builder = RunnerSequenceBuilder(
                latest_runner_builders = recover Array[RunnerBuilder val] end
                )
              runner_builders.push(seq_builder)
            end
            runner_builders.push(r_builder)
            handled_source_runners = true
          elseif not pipeline.is_coalesced() then
            if handled_source_runners then
              runner_builders.push(r_builder)
            else
              source_runner_builders.push(r_builder)
              handled_source_runners = true
            end
          // If the developer specified an id, then this needs to be on
          // a separate step to be accessed by multiple pipelines
          elseif r_builder.id() != 0 then
            runner_builders.push(r_builder)
            handled_source_runners = true
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

        let boundaries: Array[USize] = boundaries.create()
        var count: USize = 0
        for i in Range(0, worker_count) do
          count = count + per_worker
          if (i == (worker_count - 1)) and
            (count < runner_builders.size()) then
            // Make sure we cover all steps by forcing the rest on the
            // last worker if need be
            boundaries.push(runner_builders.size())
          else
            boundaries.push(count)
          end
        end

        // Keep track of which runner_builder we're on in this pipeline
        var runner_builder_idx: USize = 0
        // Keep track of which worker's boundary we're using
        var boundaries_idx: USize = 0

        // For each worker, use its boundary value to determine which
        // runner_builders to use to create StepInitializers that will be
        // added to its LocalTopology
        while boundaries_idx < boundaries.size() do
          let boundary = boundaries(boundaries_idx)

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

          // We'll use this to create the LocalTopology for this worker
          let step_initializers: Array[StepInitializer val] trn =
            recover Array[StepInitializer val] end

          // Make sure there are still runner_builders left in the pipeline.
          if runner_builder_idx < runner_builders.size() then
            var cur_step_id = _guid_gen.u128()

            // Until we hit the boundary for this worker, keep adding
            // stepinitializers from the pipeline
            while runner_builder_idx < boundary do
              var next_runner_builder: RunnerBuilder val =
                runner_builders(runner_builder_idx)

              // Stateful steps have to be handled differently since pre state
              // steps must be on the same workers as their corresponding
              // state steps
              if next_runner_builder.is_stateful() then
                // If this is partitioned state and we haven't handled this
                // shared state before, handle it.  Otherwise, just handle the
                // prestate.
                var state_name = ""
                match next_runner_builder
                | let pb: PartitionBuilder val =>
                  state_name = pb.state_name()
                  if not state_partition_map.contains(state_name) then
                    state_partition_map(state_name) = pb.partition_addresses(worker)
                  end
                end

                // Create the prestate initializer, and if this is not
                // partitioned state, then the state initializer as well
                let next_initializer: StepInitializer val =
                  match next_runner_builder
                  | let pb: PartitionBuilder val =>
                    @printf[I32](("Preparing to spin up partitioned state on " + worker + "\n").cstring())
                    PartitionedPreStateStepBuilder(
                      pb.pre_state_subpartition(worker), next_runner_builder,
                      state_name)
                  else
                    @printf[I32](("Preparing to spin up non-partitioned state computation for " + next_runner_builder.name() + " on " + worker + "\n").cstring())
                    step_initializers.push(StepBuilder(next_runner_builder,
                      next_runner_builder.id(),
                      next_runner_builder.is_stateful()))
                    steps(next_runner_builder.id()) = worker

                    runner_builder_idx = runner_builder_idx + 1

                    next_runner_builder = runner_builders(runner_builder_idx)

                    @printf[I32](("Preparing to spin up non-partitioned state for " + next_runner_builder.name() + " on " + worker + "\n").cstring())

                    StepBuilder(next_runner_builder, next_runner_builder.id(),
                      next_runner_builder.is_stateful())
                  end

                step_initializers.push(next_initializer)
                steps(next_runner_builder.id()) = worker

                cur_step_id = _guid_gen.u128()
              else
                @printf[I32](("Preparing to spin up " + next_runner_builder.name() + " on " + worker + "\n").cstring())
                let step_builder = StepBuilder(next_runner_builder,
                  cur_step_id)
                step_initializers.push(step_builder)
                steps(cur_step_id) = worker

                cur_step_id = _guid_gen.u128()
              end

              runner_builder_idx = runner_builder_idx + 1
            end
          end

          // Having prepared all the step initializers for this worker,
          // summarize this data in a WorkerTopologyData object
          try
            // This id is for the Step that will receive data via a
            // Proxy
            let boundary_step_id = step_initializers(0).id()

            let topology_data = WorkerTopologyData(worker, boundary_step_id,
              consume step_initializers)
            worker_topology_data.push(topology_data)
          end

          boundaries_idx = boundaries_idx + 1
        end

        // Set up the EgressBuilders and LocalPipelines for reach worker
        // for our current pipeline
        for i in Range(0, worker_topology_data.size()) do
          let cur =
            try
              worker_topology_data(i)
            else
              @printf[I32]("No worker topology data found!\n".cstring())
              error
            end
          let next_worker_data: (WorkerTopologyData val | None) =
            try worker_topology_data(i + 1) else None end

          let source_seq_builder = RunnerSequenceBuilder(
            source_runner_builders = recover Array[RunnerBuilder val] end)

          let source_data =
            if i == 0 then
              @printf[I32](("\nPreparing to spin up " + source_seq_builder.name() + " on source on " + cur.worker_name + "\n").cstring())
              SourceData(pipeline.source_builder(),
                source_seq_builder, source_addr)
            else
              None
            end

          // If this worker has no steps (is_empty), then create a
          // placeholder sink
          if cur.is_empty then
            let egress_builder = EgressBuilder(_output_addr, pipeline_id
              pipeline.sink_builder())
            let local_pipeline = LocalPipeline(pipeline.name(),
              cur.step_initializers, egress_builder, source_data,
              pipeline.state_builders())
            try
              local_pipelines(cur.worker_name).push(local_pipeline)
            else
              @printf[I32]("No pipeline list found!\n".cstring())
              error
            end
          // If this worker has steps, then we need either a Proxy or a sink
          else
            match next_worker_data
            | let next_w: WorkerTopologyData val =>
              // If the next worker in order has no steps, then we need a
              // sink on this worker
              if next_w.is_empty then
                let egress_builder = EgressBuilder(_output_addr, pipeline_id
                  pipeline.sink_builder())
                let local_pipeline = LocalPipeline(pipeline.name(),
                  cur.step_initializers, egress_builder, source_data,
                  pipeline.state_builders())
                try
                  local_pipelines(cur.worker_name).push(local_pipeline)
                else
                  @printf[I32]("No pipeline list found!\n".cstring())
                  error
                end
              // If the next worker has steps (continues the pipeline), then
              // we need a Proxy to it on this worker
              else
                let proxy_address = ProxyAddress(next_w.worker_name,
                  next_w.boundary_step_id)
                let egress_builder = EgressBuilder(proxy_address)
                let local_pipeline = LocalPipeline(pipeline.name(),
                  cur.step_initializers, egress_builder, source_data,
                  pipeline.state_builders())
                try
                  local_pipelines(cur.worker_name).push(local_pipeline)
                else
                  @printf[I32]("No pipeline list found!\n".cstring())
                  error
                end
              end
            // If the match fails, then this is the last worker in order and
            // we need a sink on it
            else
              let egress_builder = EgressBuilder(_output_addr, pipeline_id
                pipeline.sink_builder())
              let local_pipeline = LocalPipeline(pipeline.name(),
                cur.step_initializers, egress_builder, source_data,
                pipeline.state_builders())
              try
                local_pipelines(cur.worker_name).push(local_pipeline)
              else
                @printf[I32]("No pipeline list found!\n".cstring())
                error
              end
            end
          end
        end

        // Reset the WorkerTopologyData array for the next pipeline since
        // we've used it for this one already
        worker_topology_data = Array[WorkerTopologyData val]

        // Prepare to initialize the next pipeline
        pipeline_id = pipeline_id + 1
      end

      // Keep track of LocalTopologies that we need to send to other
      // (non-initializer) workers
      let other_local_topologies: Array[LocalTopology val] trn =
        recover Array[LocalTopology val] end

      // For each worker, generate a LocalTopology
      // from all of its LocalPipelines
      for (w, ps) in local_pipelines.pairs() do
        let pvals: Array[LocalPipeline val] trn =
          recover Array[LocalPipeline val] end
        for p in ps.values() do
          pvals.push(p)
        end
        let local_topology = LocalTopology(application.name(), consume pvals)

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

class WorkerTopologyData
  let worker_name: String
  let boundary_step_id: U128
  let step_initializers: Array[StepInitializer val] val
  let is_empty: Bool

  new val create(n: String, id: U128, si: Array[StepInitializer val] val) =>
    worker_name = n
    boundary_step_id = id
    step_initializers = si
    is_empty = (step_initializers.size() == 0)
