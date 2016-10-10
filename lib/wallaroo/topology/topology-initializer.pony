use "collections"
use "net"
use "time"
use "buffered"
use "files"
use "wallaroo/network"

// WE NEED WORKER NAMES!

primitive TopologyInitializer
  fun apply(topology: Topology val, env: Env, data_addr: Array[String],
    input_addrs: Array[Array[String]] val, 
    output_addr: Array[String], metrics_conn: TCPConnection, 
    expected: USize, init_path: String, worker_count: USize,
    is_initializer: Bool, worker_name: String, connections: Connections,
    initializer: (Initializer | None)) 
  =>
    try
      // REMOVE LATER (for try block)
      topology.pipelines(0)

      var pipeline_id: USize = 0

      // Map from step_id to worker name
      let steps: Map[U128, String] = steps.create()
      // Map from worker name to array of local pipelines
      let local_pipelines: Map[String, Array[LocalPipeline val]] =
        local_pipelines.create()

      for pipeline in topology.pipelines.values() do
        // break down into LocalPipeline objects
        // and add to local_pipelines

        let sink_addr: Array[String] trn = recover Array[String] end
        sink_addr.push(output_addr(0))
        sink_addr.push(output_addr(1))

        let sink_egress_builder = EgressBuilder(consume sink_addr, 
          pipeline.sink_runner_builder())

        // Determine which steps go on which workers using boundary indices
        let per_worker: USize = pipeline.size() / worker_count
        let boundaries: Array[USize] = boundaries.create()
        var count: USize = 0
        for i in Range(0, worker_count) do
          if (count + per_worker) < pipeline.size() then
            count = count + per_worker
            boundaries.push(count)
          else
            boundaries.push(pipeline.size() - 1)
          end
        end

        // Since we're dealing with StepBuilders, we should be able to 
        // go forward through the pipeline when building LocalPipelines
        var boundaries_idx = boundaries.size()
        var last_boundary = pipeline.size()
        while boundaries_idx > 0 do
          var last_runner = RouterRunnerBuilder
          // if boundaries(boundaries_idx) < last_boundary then
          //   // Create step builders
          // end

          // Check if this is the end to determine what kind of egress
          // egress_builder = ...
          boundaries_idx = boundaries_idx - 1
        end


        pipeline_id = pipeline_id + 1
      end

      // For each worker in local_pipelines, generate a LocalTopology

    else
      @printf[I32]("Error initializating topology!/n".cstring())
    end
