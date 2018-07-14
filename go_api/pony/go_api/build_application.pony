use "collections"
use "debug"
use "json"
use "net"
use "pony-kafka"
use "wallaroo"
use "wallaroo/core/source"
use "wallaroo/core/source/kafka_source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/sink"
use "wallaroo/core/sink/kafka_sink"
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
    match pipeline.computation_builders_map(_computation_builder_id)?
    | "ComputationMultiBuilder" =>
      steps_map(_step_id) =
        _StepInfo(steps_map(_from_step_id)?.to(
          ComputationMultiBuilder(_computation_builder_id)))
    | "ComputationBuilder" =>
      steps_map(_step_id) =
        _StepInfo(steps_map(_from_step_id)?.to(
          ComputationBuilder(_computation_builder_id)))
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

  new val create(step_id': U64, from_step_id': U64, state_computation_id: U64,
    state_builder_id: U64, state_name: String, partition_id: U64)
  =>
    _step_id = step_id'
    _from_step_id = from_step_id'
    _state_computation_id = state_computation_id
    _state_builder_id = state_builder_id
    _state_name = state_name
    _partition_id = partition_id

  fun step_id(): U64 =>
    _step_id

  fun from_step_id(): U64 =>
    _from_step_id

  fun connect(pipeline: _PipelineInfo box, steps_map: Map[U64, _StepInfo]) ? =>
    match pipeline.state_computations_map(_state_computation_id)?
    | "StateComputation" =>
      steps_map(_step_id) =
        _StepInfo(steps_map(_from_step_id)?.to_state_partition(
          StateComputation(_state_computation_id),
          StateBuilder(_state_builder_id),
          _state_name, pipeline.partitions_map(_partition_id)?))
    | "StateComputationMulti" =>
      steps_map(_step_id) =
        _StepInfo(steps_map(_from_step_id)?.to_state_partition(
          StateComputationMulti(_state_computation_id),
          StateBuilder(_state_builder_id),
          _state_name, pipeline.partitions_map(_partition_id)?))
    else
      error
    end

class val _ToSink is _Connection
  let _step_id: U64
  let _from_step_id: U64
  let _sink_config: SinkConfig[GoData]

  new val create(step_id': U64, from_step_id': U64,
    sink_config: SinkConfig[GoData])
  =>
    _step_id = step_id'
    _from_step_id = from_step_id'
    _sink_config = sink_config

  fun step_id(): U64 =>
    _step_id

  fun from_step_id(): U64 =>
    _from_step_id

  fun connect(pipeline: _PipelineInfo box, steps_map: Map[U64, _StepInfo])? =>
    steps_map(_from_step_id)?.to_sink(_sink_config)

class val _ToSinks is _Connection
  let _step_id: U64
  let _from_step_id: U64
  let _sink_configs: Array[SinkConfig[GoData]] val

  new val create(step_id': U64, from_step_id': U64,
    sink_configs: Array[SinkConfig[GoData]] val)
  =>
    _step_id = step_id'
    _from_step_id = from_step_id'
    _sink_configs = sink_configs

  fun step_id(): U64 =>
    _step_id

  fun from_step_id(): U64 =>
    _from_step_id

  fun connect(pipeline: _PipelineInfo box, steps_map: Map[U64, _StepInfo])? =>
    steps_map(_from_step_id)?.to_sinks(_sink_configs)

class val _Done is _Connection
  let _step_id: U64
  let _from_step_id: U64

  new val create(step_id': U64, from_step_id': U64) =>
    _step_id = step_id'
    _from_step_id = from_step_id'

  fun step_id(): U64 =>
    _step_id

  fun from_step_id(): U64 =>
    _from_step_id

  fun connect(pipeline: _PipelineInfo box, steps_map: Map[U64, _StepInfo])? =>
    steps_map(_from_step_id)?.done()

primitive _ConnectionFactory
  fun apply(connection_j: JsonEzData, env: Env): _Connection ? =>
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
      _ToStatePartition(step_id, from_step_id, state_computation_id,
        state_builder_id, state_name, partition_id)
    | "ToSink" =>
      let sink_j = connection_j("Sink")?
      let sink = _SinkConfig.from_json_ez_data(sink_j, env)?
      _ToSink(step_id, from_step_id, sink)
    | "ToSinks" =>
      let sinks_j = connection_j("Sinks")?
      let sinks = recover iso Array[SinkConfig[GoData]] end
      for sink_j in sinks_j.array()?.values() do
        let sink = _SinkConfig.from_json_ez_data(sink_j, env)?
        sinks.push(sink)
      end
      _ToSinks(step_id, from_step_id, consume sinks)
    | "Done" =>
      _Done(step_id, from_step_id)
    else
      Debug("Could not create connection")
      error
    end

class _StepInfo
  let _pipeline_builder: PipelineBuilder[GoData, GoData, GoData]

  new create(pipeline_builder: PipelineBuilder[GoData, GoData, GoData]) =>
    _pipeline_builder = pipeline_builder

  fun ref to(computation_builder: (ComputationBuilder | ComputationMultiBuilder)):
    PipelineBuilder[GoData, GoData, GoData]
  =>
    _pipeline_builder.to[GoData](computation_builder)

  fun ref to_state_partition(
    computation: (StateComputation | StateComputationMulti),
    state_builder: StateBuilder, name: String, partition: w.Partitions[GoData]):
    PipelineBuilder[GoData, GoData, GoData]
  =>
    _pipeline_builder.to_state_partition[GoData, GoData, GoState](
      computation, state_builder, name, partition)

  fun ref to_sink(sink_config: SinkConfig[GoData]) =>
    _pipeline_builder.to_sink(sink_config)

  fun ref to_sinks(sink_configs: Array[SinkConfig[GoData]] val) =>
    _pipeline_builder.to_sinks(sink_configs)

  fun ref done() =>
    _pipeline_builder.done()

class val _PipelineInfo
  let name: String
  let source_config: SourceConfig[GoData] val
  let computation_builders_map: Map[U64, String] val
  let state_computations_map: Map[U64, String] val
  let partitions_map: Map[U64, w.Partitions[GoData]] val
  let connections: Array[_Connection] val

  new val create(name': String,
    source_config': SourceConfig[GoData] val,
    computation_builders_map': Map[U64, String] val,
    state_computations_map': Map[U64, String] val,
    partitions_map': Map[U64, w.Partitions[GoData]] val,
    connections': Array[_Connection] val)
  =>
    name = name'
    source_config = source_config'
    computation_builders_map = computation_builders_map'
    state_computations_map = state_computations_map'
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
  fun from_json_ez_data(partition_j: JsonEzData): w.Partitions[GoData] ? =>
    let clz = partition_j("Class")?.string()?
    let pfid = partition_j("PartitionFunctionId")?.int()?.u64()
    let plid = partition_j("PartitionListId")?.int()?.u64()
    let pid = partition_j("PartitionId")?.int()?.u64()

    match clz
    | "PartitionU64" =>
      w.Partitions[GoData](
        PartitionFunction(pfid), PartitionList(plid))
    else
      error
    end

primitive _SourceConfig
  fun from_json_ez_data(source: JsonEzData, env: Env): SourceConfig[GoData] val ? =>
    match source("Class")?.string()?
    | "TCPSource" =>
      let host = source("Host")?.string()?
      let port = source("Port")?.string()?
      let decoder_id = source("DecoderId")?.int()?.u64()
      TCPSourceConfig[GoData](GoFramedSourceHandler(decoder_id), host, port)
    | "KafkaSource" =>
      let kafka_source_name = source("Name")?.string()?

      let ksclip = KafkaSourceConfigCLIParser(env.out, kafka_source_name)
      let ksco = ksclip.parse_options(env.args)?

      let decoder_id = source("DecoderId")?.int()?.u64()

      KafkaSourceConfig[GoData](consume ksco, env.root as TCPConnectionAuth,
        GoSourceHandler(decoder_id))
    else
      error
    end

primitive _SinkConfig
  fun from_json_ez_data(sink: JsonEzData, env: Env): SinkConfig[GoData] val ? =>
    match sink("Class")?.string()?
    | "TCPSink" =>
      let host = sink("Host")?.string()?
      let port = sink("Port")?.string()?
      let encoderId = sink("EncoderId")?.int()?.u64()
      TCPSinkConfig[GoData](GoEncoder(encoderId), host, port)
    | "KafkaSink" =>
      let kafka_sink_name = sink("Name")?.string()?

      let encoder_id = sink("EncoderId")?.int()?.u64()

      let ksclip = KafkaSinkConfigCLIParser(env.out, kafka_sink_name)
      let ksco = ksclip.parse_options(env.args)?

      KafkaSinkConfig[GoData](GoKafkaEncoder(encoder_id), consume ksco,
        env.root as TCPConnectionAuth)
    else
      error
    end

primitive BuildApplication
  fun from_json(json_str: String, env: Env): (Application val, String) ? =>
    try
      let json_doc: JsonDoc = JsonDoc
      json_doc.parse(json_str)?

      let jez = JsonEz(json_doc)

      let application_name = jez()("Name")?.string()?

      let pipelines: Array[_PipelineInfo] trn = recover Array[_PipelineInfo] end

      let pipelines_j = jez()("Pipelines")?
      let pipelines_j_array = pipelines_j.array()?
      for pipeline in pipelines_j_array.values() do
        let source = _SourceConfig.from_json_ez_data(pipeline("Source")?, env)?
        let name = pipeline("Name")?.string()?

        let components = pipeline("Components")?
        let components_array = components.array()?

        let computation_builders_map = recover trn Map[U64, String] end
        let state_computations_map = recover trn Map[U64, String] end

        for component_json in components_array.values() do
          let clz = component_json("Class")?.string()?
          let cid = component_json("ComponentId")?.int()?.u64()
          match clz
          | "ComputationBuilder" => computation_builders_map(cid) = clz
          | "ComputationMultiBuilder" => computation_builders_map(cid) = clz
          | "StateComputation" => state_computations_map(cid) = clz
          | "StateComputationMulti" => state_computations_map(cid) = clz
          end
        end
        Debug("Read components")

        let partitions = pipeline("Partitions")?
        let partitions_array = partitions.array()?

        let partitions_map =
          recover trn Map[U64, w.Partitions[GoData]] end

        for partition_json in partitions_array.values() do
          let pid = partition_json("PartitionId")?.int()?.u64()
          partitions_map(pid) = _Partition.from_json_ez_data(partition_json)?
        end

        Debug("Read partitions")

        let connections_j = pipeline("Connections")?
        let connections_array = connections_j.array()?

        let connections = recover trn Array[_Connection] end

        for connection_j in connections_array.values() do
          connections.push(_ConnectionFactory(connection_j, env)?)
        end

        Debug("Read connections")

        pipelines.push(_PipelineInfo(name, source,
          consume computation_builders_map, consume state_computations_map,
          consume partitions_map, consume connections))
      end
      (_build_application(application_name, consume pipelines)?, application_name)
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
