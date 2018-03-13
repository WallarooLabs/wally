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

use "collections"
use "net"
use "pony-kafka"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
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
  let _auth: TCPConnectionAuth

  new val create(ksco: KafkaConfigOptions val, auth: TCPConnectionAuth) =>
    _ksco = ksco
    _auth = auth

  fun apply(source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry, route_builder: RouteBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    target_router: Router = EmptyRouter): KafkaSourceListenerBuilder[In]
  =>
    KafkaSourceListenerBuilder[In](source_builder, router, router_registry,
      route_builder,
      outgoing_boundary_builders, event_log, auth,
      layout_initializer, consume metrics_reporter, target_router, _ksco,
      _auth)

class val KafkaSourceListenerBuilder[In: Any val]
  let _step_id_gen: StepIdGenerator = StepIdGenerator
  let _source_builder: SourceBuilder
  let _router: Router
  let _router_registry: RouterRegistry
  let _route_builder: RouteBuilder
  let _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _layout_initializer: LayoutInitializer
  let _event_log: EventLog
  let _auth: AmbientAuth
  let _target_router: Router
  let _metrics_reporter: MetricsReporter
  let _ksco: KafkaConfigOptions val
  let _tcp_auth: TCPConnectionAuth

  new val create(source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry, route_builder: RouteBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    target_router: Router = EmptyRouter,
    ksco: KafkaConfigOptions val, tcp_auth: TCPConnectionAuth)
  =>
    _source_builder = source_builder
    _router = router
    _router_registry = router_registry
    _route_builder = route_builder
    _outgoing_boundary_builders = outgoing_boundary_builders
    _layout_initializer = layout_initializer
    _event_log = event_log
    _auth = auth
    _target_router = target_router
    _metrics_reporter = consume metrics_reporter
    _ksco = ksco
    _tcp_auth = tcp_auth

  fun apply(env: Env): SourceListener =>
    KafkaSourceListener[In](env, _source_builder, _router, _router_registry,
      _route_builder, _outgoing_boundary_builders,
      _event_log, _auth, _layout_initializer, _metrics_reporter.clone(),
      _target_router, _ksco, _tcp_auth)


class MapPartitionConsumerMessageHandler is KafkaConsumerMessageHandler
  let _consumers: Map[I32, KafkaConsumer tag] val

  new create(consumers: Map[I32, KafkaConsumer tag] val) =>
    _consumers = consumers

  fun ref apply(consumers: Array[KafkaConsumer tag] val,
    key: (Array[U8] box | None), msg_metadata: KafkaMessageMetadata val):
    (KafkaConsumer tag | None)
  =>
    try _consumers(msg_metadata.get_partition_id())? end

  fun clone(): KafkaConsumerMessageHandler iso^ =>
    recover iso MapPartitionConsumerMessageHandler(_consumers) end


actor KafkaSourceListener[In: Any val] is (SourceListener & KafkaClientManager)
  let _env: Env
  let _notify: KafkaSourceListenerNotify[In]
  var _router: Router
  let _router_registry: RouterRegistry
  let _route_builder: RouteBuilder
  var _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _layout_initializer: LayoutInitializer
  let _metrics_reporter: MetricsReporter
  let _ksco: KafkaConfigOptions val
  let _tcp_auth: TCPConnectionAuth
  let _kc: (KafkaClient tag | None)
  let _kafka_topic_partition_sources: Map[String, Map[I32, KafkaSource[In]]] =
    _kafka_topic_partition_sources.create()

  new create(env: Env, source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry, route_builder: RouteBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    target_router: Router = EmptyRouter,
    ksco: KafkaConfigOptions val, tcp_auth: TCPConnectionAuth)
  =>
    _env = env
    _notify = KafkaSourceListenerNotify[In](source_builder, event_log, auth,
      target_router)
    _router = router
    _router_registry = router_registry
    _route_builder = route_builder
    _outgoing_boundary_builders = outgoing_boundary_builders
    _layout_initializer = layout_initializer
    _metrics_reporter = consume metrics_reporter

    _ksco = ksco
    _tcp_auth = tcp_auth

    match router
    | let pr: PartitionRouter =>
      _router_registry.register_partition_router_subscriber(pr.state_name(),
        this)
    | let spr: StatelessPartitionRouter =>
      _router_registry.register_stateless_partition_router_subscriber(
        spr.partition_id(), this)
    end


    // create kafka config
    _kc = match KafkaConfigFactory(_ksco, _env.out)
    | let kc: KafkaConfig val =>
      for topic in kc.consumer_topics.values() do
        _kafka_topic_partition_sources(topic) = Map[I32, KafkaSource[In]]
      end
      // create kafka client
      KafkaClient(_tcp_auth, kc, this)
    | let ksce: KafkaConfigError =>
      @printf[U32]("%s\n".cstring(), ksce.message().cstring())
      Fail()
      None
    end

  be kafka_client_error(error_report: KafkaErrorReport) =>
    @printf[I32](("ERROR: Kafka client encountered an unrecoverable error! " +
      error_report.string() + "\n").cstring())

    Fail()

  be receive_kafka_topics_partitions(new_topic_partitions: Map[String,
    (KafkaTopicType, Set[I32])] val)
  =>
    var partitions_changed: Bool = false

    for (topic, (ktt, new_partitions)) in new_topic_partitions.pairs() do
      if (ktt isnt KafkaConsumeOnly) and (ktt isnt KafkaProduceAndConsume) then
        continue
      end
      let partitions_sources = try
             _kafka_topic_partition_sources(topic)?
           else
             let m = Map[I32, KafkaSource[In]]
             _kafka_topic_partition_sources(topic) = m
             m
           end
      if new_partitions.size() != partitions_sources.size() then
        partitions_changed = true
      end

      for part_id in new_partitions.values() do
        if not partitions_sources.contains(part_id) then
          partitions_changed = true

          try
            match _kc
            | let kc: KafkaClient tag =>
              let source_id = _step_id_gen()
              let source = KafkaSource[In](source_id, this,
                _notify.build_source(_env)?, _router.routes(), _route_builder,
                _outgoing_boundary_builders, _layout_initializer,
                _metrics_reporter.clone(), topic, part_id, kc,
                _router_registry)
              partitions_sources(part_id) = source
              _router_registry.register_source(source, source_id)
              match _router
              | let pr: PartitionRouter =>
                _router_registry.register_partition_router_subscriber(pr.state_name(), source)
              | let spr: StatelessPartitionRouter =>
                _router_registry.register_stateless_partition_router_subscriber(
                  spr.partition_id(), source)
              end
            else
              @printf[I32]("Error _kc as None instead of KafkaClient!\n"
                .cstring())
              Unreachable()
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
        let my_consumers: Map[I32, KafkaConsumer tag] iso = recover iso
          Map[I32, KafkaConsumer tag] end
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
    end

  be update_router(router: Router) =>
    _router = router
    _notify.update_router(router)

  be remove_route_for(moving_step: Consumer) =>
    None

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
