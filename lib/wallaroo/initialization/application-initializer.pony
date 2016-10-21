use "collections"
use "net"
use "sendence/guid"
use "sendence/messages"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

actor ApplicationInitializer
  let _guid_gen: GuidGenerator = GuidGenerator
  let _local_topology_initializer: LocalTopologyInitializer
  let _input_addrs: Array[Array[String]] val
  let _output_addr: Array[String] val
  let _is_automated: Bool

  var _application_starter: (ApplicationStarter val | None) = None
  var _application: (Application val | None) = None

  new create(local_topology_initializer: LocalTopologyInitializer,
    input_addrs: Array[Array[String]] val, 
    output_addr: Array[String] val, is_automated: Bool) 
  =>
    _local_topology_initializer = local_topology_initializer
    _input_addrs = input_addrs
    _output_addr = output_addr
    _is_automated = is_automated

  be update_application(a: (ApplicationStarter val | Application val)) =>
    match a
    | let s: ApplicationStarter val =>
      _application_starter = s
    | let app: Application val =>
      _application = app
    end

  be initialize(worker_initializer: WorkerInitializer, worker_count: USize, 
    worker_names: Array[String] val)
  =>
    @printf[I32]("Initializing application\n".cstring())
    if _is_automated then
      @printf[I32]("Automating...\n".cstring())
      match _application
      | let a: Application val =>
        _automate_initialization(a, worker_initializer, worker_count, 
          worker_names)
      end
    else
      match _application_starter
      | let a: ApplicationStarter val =>
        @printf[I32]("Using user-defined ApplicationStarter...\n".cstring())
        try
          a(worker_initializer, worker_names, _input_addrs, worker_count)
        else
          @printf[I32]("Error running ApplicationStarter.\n".cstring())
        end
      else
        @printf[I32]("No application starter!\n".cstring())
      end
    end

  fun ref _automate_initialization(application: Application val,
    worker_initializer: WorkerInitializer, worker_count: USize,
    worker_names: Array[String] val) 
  =>
    try
      // REMOVE LATER (for try block)
      application.pipelines(0)

      let worker_topology_data = Array[WorkerTopologyData val]

      var pipeline_id: USize = 0

      // Map from step_id to worker name
      let steps: Map[U128, String] = steps.create()
      // Map from worker name to array of local pipelines
      let local_pipelines: Map[String, Array[LocalPipeline val]] =
        local_pipelines.create()

      local_pipelines("initializer") = Array[LocalPipeline val]
      for name in worker_names.values() do
        local_pipelines(name) = Array[LocalPipeline val]
      end

      for pipeline in application.pipelines.values() do
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
        let per_worker: USize = pipeline.size() / worker_count
        let boundaries: Array[ISize] = boundaries.create()
        var count: USize = 0
        for i in Range(0, worker_count) do
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
              worker_names(boundaries_idx - 1)
            end
          let next_worker: (String | None) = 
            try
              worker_names(boundaries_idx)
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
        let local_topology = LocalTopology(application.name(), consume pvals)

        if w == "initializer" then
          _local_topology_initializer.update_topology(local_topology)
          _local_topology_initializer.initialize() 
        else
          other_local_topologies.push(local_topology)
        end
      end

      match worker_initializer
      | let wi: WorkerInitializer =>
        wi.distribute_local_topologies(consume other_local_topologies)
      else
        @printf[I32]("Error distributing local topologies!/n".cstring())
      end
    else
      @printf[I32]("Error initializating application!/n".cstring())
    end


class WorkerTopologyData
  let worker_name: String
  let boundary_step_id: U128
  let step_builders: Array[StepBuilder val] val

  new val create(n: String, id: U128, sb: Array[StepBuilder val] val) =>
    worker_name = n
    boundary_step_id = id
    step_builders = sb