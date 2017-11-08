use "collections"
use "debug"
use "json"
use "wallaroo"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/sink"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/state"
use w = "wallaroo/core/topology"
use "../json_ez"

trait val _Connection
  fun step_id(): U64
  fun from_step_id(): U64
  fun connect(pipeline: _PipelineInfo box, steps_map: Map[U64, _StepInfo]) ?

class val _ToComputation is _Connection
  let _step_id: U64
  let _from_step_id: U64
  let _computation_builder_id: U64

  new val create(step_id': U64, from_step_id': U64, computation_builder_id: U64) =>
    _step_id = step_id'
    _from_step_id = from_step_id'
    _computation_builder_id = computation_builder_id

  fun step_id(): U64 =>
    _step_id

  fun from_step_id(): U64 =>
    _from_step_id

  fun connect(pipeline: _PipelineInfo box, steps_map: Map[U64, _StepInfo]) ? =>
    match pipeline.components_map(_computation_builder_id)?
    | "ComputationMultiBuilder" =>
      steps_map(_step_id) =
        _StepInfo(steps_map(_from_step_id)?.to(
          ComputationMultiBuilder(_computation_builder_id)))
    | "ComputationBuilder" =>
      // TODO: add computation builder
      error
    else
      error
    end

class val _ToStatePartition is _Connection
  let _step_id: U64
  let _from_step_id: U64
  let _state_computation_id: U64
  let _state_builder_id: U64
  let _state_name: String
  let _partition_id: U64
  let _multi_worker: Bool

  new val create(step_id': U64, from_step_id': U64, state_computation_id: U64,
    state_builder_id: U64, state_name: String, partition_id: U64,
    multi_worker: Bool)
  =>
    _step_id = step_id'
    _from_step_id = from_step_id'
    _state_computation_id = state_computation_id
    _state_builder_id = state_builder_id
    _state_name = state_name
    _partition_id = partition_id
    _multi_worker = multi_worker

  fun step_id(): U64 =>
    _step_id

  fun from_step_id(): U64 =>
    _from_step_id

  fun connect(pipeline: _PipelineInfo box, steps_map: Map[U64, _StepInfo]) ? =>
    match pipeline.components_map(_state_computation_id)?
    | "StateComputation" =>
      steps_map(_step_id) =
        _StepInfo(steps_map(_from_step_id)?.to_state_partition(
          StateComputation(_state_computation_id),
          StateBuilder(_state_builder_id),
          _state_name, pipeline.partitions_map(_partition_id)?,
          _multi_worker))
    | "StateComputationMulti" =>
      // TODO: add computation builder
      error
    else
      error
    end

class val _ToSink is _Connection
  let _step_id: U64
  let _from_step_id: U64
  let _sink_config: TCPSinkConfig[GoData]

  new val create(step_id': U64, from_step_id': U64,
    sink_config: TCPSinkConfig[GoData])
  =>
    _step_id = step_id'
    _from_step_id = from_step_id'
    _sink_config = sink_config

  fun step_id(): U64 =>
    _step_id

  fun from_step_id(): U64 =>
    _from_step_id

  fun connect(pipeline: _PipelineInfo box, steps_map: Map[U64, _StepInfo])? =>
    steps_map(_from_step_id)?.to_sink(_sink_config)?

primitive _ConnectionFactory
  fun apply(connection_j: JsonEzData): _Connection ? =>
    let step_id = connection_j("StepId")?.int()?.u64()
    let from_step_id = connection_j("FromStepId")?.int()?.u64()
    match connection_j("Class")?.string()?
    | "ToComputation" =>
      let computation_builder_id =
        connection_j("ComputationBuilderId")?.int()?.u64()
      _ToComputation(step_id, from_step_id, computation_builder_id)
    | "ToStatePartition" =>
      let state_computation_id =
        connection_j("StateComputationId")?.int()?.u64()
      let state_builder_id = connection_j("StateBuilderId")?.int()?.u64()
      let state_name = connection_j("StateName")?.string()?
      let partition_id = connection_j("PartitionId")?.int()?.u64()
      let multi_worker = try
        connection_j("MultiWorker")?.bool()?
      else
        false
      end
      _ToStatePartition(step_id, from_step_id, state_computation_id,
        state_builder_id, state_name, partition_id, multi_worker)
    | "ToSink" =>
      let sink_j = connection_j("Sink")?
      let sink = _SinkConfig.from_json_ez_data(sink_j)?
      _ToSink(step_id, from_step_id, sink)
    else
      Debug("Could not create connection")
      error
    end

class _StepInfo
  let _pipeline_builder: PipelineBuilder[GoData, GoData, GoData]

  new create(pipeline_builder: PipelineBuilder[GoData, GoData, GoData]) =>
    _pipeline_builder = pipeline_builder

  fun ref to(computation_builder: ComputationMultiBuilder):
    PipelineBuilder[GoData, GoData, GoData]
  =>
    _pipeline_builder.to[GoData](computation_builder)

  fun ref to_state_partition(
    computation: w.StateComputation[GoData, GoData, GoState] val,
    state_builder: StateBuilder, name: String, partition: w.Partition[GoData, U64],
    multi_worker: Bool):
    PipelineBuilder[GoData, GoData, GoData]
  =>
    _pipeline_builder.to_state_partition[GoData, U64, GoData, GoState](
      computation, state_builder, name, partition, multi_worker)

  fun ref to_sink(sink_config: SinkConfig[GoData])? =>
    _pipeline_builder.to_sink(sink_config)?

class val _PipelineInfo
  let name: String
  let source_config: TCPSourceConfig[GoData] val
  let components_map: Map[U64, String] val
  let partitions_map: Map[U64, w.Partition[GoData, U64]] val
  let connections: Array[_Connection] val

  new val create(name': String,
    source_config': TCPSourceConfig[GoData] val,
    components_map': Map[U64, String] val,
    partitions_map': Map[U64, w.Partition[GoData, U64]] val,
    connections': Array[_Connection] val)
  =>
    name = name'
    source_config = source_config'
    components_map = components_map'
    partitions_map = partitions_map'
    connections = connections'

  fun connect(application: Application) ? =>
    let pipeline = application.new_pipeline[GoData, GoData](
      name, source_config)

    let steps = Map[U64, _StepInfo]
    steps(0) = _StepInfo(pipeline)

    for c in connections.values() do
      Debug("connecting")
      c.connect(this, steps)?
      Debug("connected")
    end

primitive _Partition
  fun from_json_ez_data(partition_j: JsonEzData): w.Partition[GoData, U64] ? =>
    let clz = partition_j("Class")?.string()?
    let pfid = partition_j("PartitionFunctionId")?.int()?.u64()
    let plid = partition_j("PartitionListId")?.int()?.u64()
    let pid = partition_j("PartitionId")?.int()?.u64()

    match clz
    | "PartitionU64" =>
      w.Partition[GoData, U64](
        PartitionFunctionU64(6), PartitionListU64(7))
    else
      error
    end

primitive _SourceConfig
  fun from_json_ez_data(source: JsonEzData): TCPSourceConfig[GoData] val ? =>
    match source("Class")?.string()?
    | "TCPSource" =>
      let host = source("Host")?.string()?
      let port = source("Port")?.string()?
      let decoder_id = source("DecoderId")?.int()?.u64()
      TCPSourceConfig[GoData](GoDecoder(decoder_id), host, port)
    else
      error
    end

primitive _SinkConfig
  fun from_json_ez_data(sink: JsonEzData): TCPSinkConfig[GoData] val ? =>
    match sink("Class")?.string()?
    | "TCPSink" =>
      let host = sink("Host")?.string()?
      let port = sink("Port")?.string()?
      let encoderId = sink("EncoderId")?.int()?.u64()
      TCPSinkConfig[GoData](GoEncoder(encoderId), host, port)
    else
      error
    end

primitive BuildApplication
  fun from_json(json_str: String): Application val ? =>
    try
      let json_doc: JsonDoc = JsonDoc
      json_doc.parse(json_str)?

      let jez = JsonEz(json_doc)

      let application_name = jez()("Name")?.string()?

      let pipelines: Array[_PipelineInfo] trn = recover Array[_PipelineInfo] end

      let pipelines_j = jez()("Pipelines")?
      let pipelines_j_array = pipelines_j.array()?
      for pipeline in pipelines_j_array.values() do
        let source = _SourceConfig.from_json_ez_data(pipeline("Source")?)?
        let name = pipeline("Name")?.string()?

        let components = pipeline("Components")?
        let components_array = components.array()?

        let components_map = recover trn Map[U64, String] end

        for component_json in components_array.values() do
          let clz = component_json("Class")?.string()?
          let cid = component_json("ComponentId")?.int()?.u64()
          components_map(cid) = clz
        end
        Debug("Read components")

        let partitions = pipeline("Partitions")?
        let partitions_array = partitions.array()?

        let partitions_map =
          recover trn Map[U64, w.Partition[GoData, U64]] end

        for partition_json in partitions_array.values() do
          let pid = partition_json("PartitionId")?.int()?.u64()
          partitions_map(pid) = _Partition.from_json_ez_data(partition_json)?
        end

        Debug("Read partitions")

        let connections_j = pipeline("Connections")?
        let connections_array = connections_j.array()?

        let connections = recover trn Array[_Connection] end

        for connection_j in connections_array.values() do
          connections.push(_ConnectionFactory(connection_j)?)
        end

        Debug("Read connections")

        pipelines.push(_PipelineInfo(name, source, consume components_map,
          consume partitions_map, consume connections))
      end
      _build_application(application_name, consume pipelines)?
    else
      Debug("Error building application")
      error
    end

  fun _build_application(name: String, pipelines: Array[_PipelineInfo] val):
    Application val ?
  =>
    recover
      let application = Application(name)
      for pipeline_info in pipelines.values() do
        pipeline_info.connect(application)?
      end
      application
    end
