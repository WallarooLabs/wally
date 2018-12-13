/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "buffered"
use "collections"
use "crypto"
use "net"
use "pony-kafka"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/partitioning"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"

class val KafkaSourceListenerBuilderBuilder[In: Any val]
  let _ksco: KafkaConfigOptions val
  let _handler: SourceHandler[In] val
  let _tcp_auth: TCPConnectionAuth

  new val create(ksco: KafkaConfigOptions val, handler: SourceHandler[In] val,
    tcp_auth: TCPConnectionAuth)
  =>
    _ksco = ksco
    _handler = handler
    _tcp_auth = tcp_auth

  fun apply(worker_name: String, pipeline_name: String,
    runner_builder: RunnerBuilder, partitioner_builder: PartitionerBuilder,
    router: Router, metrics_conn: MetricsSink,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    recovering: Bool, target_router: Router = EmptyRouter):
    KafkaSourceListenerBuilder[In]
  =>
    KafkaSourceListenerBuilder[In](worker_name, pipeline_name, runner_builder,
      partitioner_builder, router, metrics_conn, consume metrics_reporter,
      router_registry, outgoing_boundary_builders, event_log, auth,
      layout_initializer, recovering, target_router, _ksco, _handler,
      _tcp_auth)

class val KafkaSourceListenerBuilder[In: Any val]
  let _worker_name: WorkerName
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder
  let _partitioner_builder: PartitionerBuilder
  let _router: Router
  let _metrics_conn: MetricsSink
  let _metrics_reporter: MetricsReporter
  let _router_registry: RouterRegistry
  let _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _event_log: EventLog
  let _auth: AmbientAuth
  let _layout_initializer: LayoutInitializer
  let _recovering: Bool
  let _target_router: Router
  let _ksco: KafkaConfigOptions val
  let _handler: SourceHandler[In] val
  let _tcp_auth: TCPConnectionAuth

  new val create(worker_name: WorkerName, pipeline_name: String,
    runner_builder: RunnerBuilder, partitioner_builder: PartitionerBuilder,
    router: Router, metrics_conn: MetricsSink,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    recovering: Bool, target_router: Router, ksco: KafkaConfigOptions val,
    handler: SourceHandler[In] val, tcp_auth: TCPConnectionAuth)
  =>
    _worker_name = worker_name
    _pipeline_name = pipeline_name
    _runner_builder = runner_builder
    _partitioner_builder = partitioner_builder
    _router = router
    _metrics_conn = metrics_conn
    _metrics_reporter = consume metrics_reporter
    _router_registry = router_registry
    _outgoing_boundary_builders = outgoing_boundary_builders
    _event_log = event_log
    _auth = auth
    _layout_initializer = layout_initializer
    _recovering = recovering
    _target_router = target_router
    _ksco = ksco
    _handler = handler
    _tcp_auth = tcp_auth

  fun apply(env: Env): SourceListener =>
    KafkaSourceListener[In](env, _worker_name, _pipeline_name, _runner_builder,
      _partitioner_builder, _router, _metrics_conn, _metrics_reporter.clone(),
      _router_registry,
      _outgoing_boundary_builders, _event_log, _auth, _layout_initializer,
      _recovering, _target_router, _ksco, _handler, _tcp_auth)

class MapPartitionConsumerMessageHandler is KafkaConsumerMessageHandler
  let _consumers: Map[KafkaPartitionId, KafkaConsumer tag] val

  new create(consumers: Map[KafkaPartitionId, KafkaConsumer tag] val) =>
    _consumers = consumers

  fun ref apply(consumers: Array[KafkaConsumer tag] val,
    key: (Array[U8] box | None), msg_metadata: KafkaMessageMetadata val):
    (KafkaConsumer tag | None)
  =>
    try _consumers(msg_metadata.get_partition_id())? end

  fun clone(): KafkaConsumerMessageHandler iso^ =>
    recover iso MapPartitionConsumerMessageHandler(_consumers) end


actor KafkaSourceListener[In: Any val] is (SourceListener & KafkaClientManager)
  let _routing_id_gen: RoutingIdGenerator = RoutingIdGenerator
  let _env: Env

  let _worker_name: WorkerName
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder
  let _partitioner_builder: PartitionerBuilder
  var _router: Router
  let _metrics_conn: MetricsSink
  let _metrics_reporter: MetricsReporter
  let _router_registry: RouterRegistry
  var _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _event_log: EventLog
  let _auth: AmbientAuth
  let _layout_initializer: LayoutInitializer
  var _recovering: Bool
  let _target_router: Router
  let _ksco: KafkaConfigOptions val
  let _handler: SourceHandler[In] val
  let _tcp_auth: TCPConnectionAuth

  let _notify: KafkaSourceListenerNotify[In]

  var _kc: (KafkaClient tag | None) = None
  let _kafka_topic_partition_sources:
    Map[String, Map[KafkaPartitionId, KafkaSource[In]]] =
    _kafka_topic_partition_sources.create()
  let _rb: Reader = Reader

  new create(env: Env, worker_name: WorkerName, pipeline_name: String,
    runner_builder: RunnerBuilder, partitioner_builder: PartitionerBuilder,
    router: Router, metrics_conn: MetricsSink,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    recovering: Bool, target_router: Router, ksco: KafkaConfigOptions val,
    handler: SourceHandler[In] val, tcp_auth: TCPConnectionAuth)
  =>
    _env = env
    _worker_name = worker_name
    _pipeline_name = pipeline_name
    _runner_builder = runner_builder
    _partitioner_builder = partitioner_builder
    _router = router
    _metrics_conn = metrics_conn
    _metrics_reporter = consume metrics_reporter
    _router_registry = router_registry
    _outgoing_boundary_builders = outgoing_boundary_builders
    _event_log = event_log
    _auth = auth
    _layout_initializer = layout_initializer
    _recovering = recovering
    _target_router = target_router
    _ksco = ksco
    _handler = handler
    _tcp_auth = tcp_auth

    _notify = KafkaSourceListenerNotify[In](_pipeline_name, _auth,
      _handler, _runner_builder, _partitioner_builder, _router,
      _metrics_reporter.clone(), _event_log, _target_router)

    match router
    | let pr: StatePartitionRouter =>
      _router_registry.register_partition_router_subscriber(pr.step_group(),
        this)
    | let spr: StatelessPartitionRouter =>
      _router_registry.register_stateless_partition_router_subscriber(
        spr.partition_routing_id(), this)
    end

  be start_listening() =>
    // create kafka client
    _kc = match KafkaConfigFactory(_ksco, _env.out)
    | let kc: KafkaConfig val =>
      for topic in kc.consumer_topics.values() do
        _kafka_topic_partition_sources(topic) =
          Map[KafkaPartitionId, KafkaSource[In]]
      end
      // create kafka client
      KafkaClient(_tcp_auth, kc, this)
    | let ksce: KafkaConfigError =>
      @printf[U32]("%s\n".cstring(), ksce.message().cstring())
      Fail()
      None
    end
    ifdef debug then
      @printf[I32]("Client for %s now created\n".cstring(),
        _pipeline_name.cstring())
    end

  be recovery_protocol_complete() =>
    None

  be kafka_client_error(client: KafkaClient, error_report: KafkaErrorReport) =>
    @printf[I32](("ERROR: Kafka client encountered an unrecoverable error! " +
      error_report.string() + "\n").cstring())

    Fail()

  be receive_kafka_topics_partitions(client: KafkaClient, new_topic_partitions:
    Map[String, (KafkaTopicType, Set[KafkaPartitionId])] val)
  =>
    var partitions_changed: Bool = false

    for (topic, (ktt, new_partitions)) in new_topic_partitions.pairs() do
      if (ktt isnt KafkaConsumeOnly) and (ktt isnt KafkaProduceAndConsume) then
        continue
      end
      let partitions_sources = try
             _kafka_topic_partition_sources(topic)?
           else
             let m = Map[KafkaPartitionId, KafkaSource[In]]
             _kafka_topic_partition_sources(topic) = m
             m
           end
      if new_partitions.size() != partitions_sources.size() then
        partitions_changed = true
      end

      for part_id in new_partitions.values() do
        if not partitions_sources.contains(part_id) then
          partitions_changed = true

          match _kc
          | let kc: KafkaClient tag =>
            // generate md5 hash for source id
            let name = _pipeline_name + " source" + "-" + topic + "-" +
              part_id.string()
            let temp_id = MD5(name)
            _rb.append(temp_id)

            let source_id = try _rb.u128_le()? else Fail(); 0 end

            let source = KafkaSource[In](source_id, _auth, name, this,
              _notify.build_source(source_id, _env), _event_log,
              _router, _outgoing_boundary_builders,
              _layout_initializer, _metrics_reporter.clone(), topic, part_id,
              kc, _router_registry, _recovering)
            partitions_sources(part_id) = source
            _router_registry.register_source(source, source_id)
            match _router
            | let pr: StatePartitionRouter =>
              _router_registry.register_partition_router_subscriber(
                pr.step_group(), source)
            | let spr: StatelessPartitionRouter =>
              _router_registry.register_stateless_partition_router_subscriber(
                spr.partition_routing_id(), source)
            end
          else
            @printf[I32](("Error creating KafkaSource for topic: " + topic
              + " and partition: " + part_id.string() + "!").cstring())
            Fail()
          end
        end
      end
    end

    if partitions_changed then
      // Replace consumer_message_handler with KafkaClient with one that knows
      // about the latest mappings
      // TODO: add logic to update starting offsets to consume from kafka
      for (topic, consumers) in _kafka_topic_partition_sources.pairs() do
        let my_consumers: Map[KafkaPartitionId, KafkaConsumer tag] iso =
          recover iso Map[KafkaPartitionId, KafkaConsumer tag] end
        for (part_id, consumer) in consumers.pairs() do
          my_consumers(part_id) = consumer
        end

        match _kc
        | let kc: KafkaClient tag =>
          kc.update_consumer_message_handler(topic, recover val
            MapPartitionConsumerMessageHandler(consume my_consumers) end)
        else
          @printf[I32]("Error _kc as None instead of KafkaClient!\n"
            .cstring())
          Unreachable()
        end
      end

      // if we were recovering upon startup, that only applies to initial
      // KafkaSources created and not to any new KafkaSources (for new
      // partitions added on the kafka broker side after the fact) so we set
      // _recovering to false
      _recovering = false
    end

  be update_router(router: Router) =>
    _router = router

  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  =>
    let new_builders: Map[String, OutgoingBoundaryBuilder val] trn =
      recover Map[String, OutgoingBoundaryBuilder val] end
    // TODO: A persistent map on the field would be much more efficient here
    for (target_worker_name, builder) in _outgoing_boundary_builders.pairs() do
      new_builders(target_worker_name) = builder
    end
    for (target_worker_name, builder) in boundary_builders.pairs() do
      if not new_builders.contains(target_worker_name) then
        new_builders(target_worker_name) = builder
      end
    end
    _outgoing_boundary_builders = consume new_builders

  be add_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    None

  be update_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  =>
    _outgoing_boundary_builders = boundary_builders

  be remove_boundary(worker: String) =>
    let new_boundary_builders =
      recover iso Map[String, OutgoingBoundaryBuilder] end
    for (w, b) in _outgoing_boundary_builders.pairs() do
      if w != worker then new_boundary_builders(w) = b end
    end

    _outgoing_boundary_builders = consume new_boundary_builders

  be dispose() =>
    None
