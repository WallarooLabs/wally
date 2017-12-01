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
use "pony-kafka"
use "wallaroo_labs/guid"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"

actor KafkaSource[In: Any val] is (Producer & KafkaConsumer)
  let _step_id_gen: StepIdGenerator = StepIdGenerator
  let _routes: MapIs[Consumer, Route] = _routes.create()
  let _route_builder: RouteBuilder
  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()
  let _layout_initializer: LayoutInitializer
  var _unregistered: Bool = false

  let _metrics_reporter: MetricsReporter

  let _listen: KafkaSourceListener[In]
  let _notify: KafkaSourceNotify[In]

  var _muted: Bool = true
  let _muted_downstream: SetIs[Any tag] = _muted_downstream.create()

  let _router_registry: RouterRegistry

  // Producer (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  let _topic: String
  let _partition_id: I32
  let _kc: KafkaClient tag

  new create(listen: KafkaSourceListener[In],
    notify: KafkaSourceNotify[In] iso,
    routes: Array[Consumer] val, route_builder: RouteBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    layout_initializer: LayoutInitializer,
    default_target: (Consumer | None) = None,
    forward_route_builder: (RouteBuilder | None) = None,
    metrics_reporter: MetricsReporter iso,
    topic: String, partition_id: I32, kafka_client: KafkaClient tag,
    router_registry: RouterRegistry)
  =>
    _topic = topic
    _partition_id = partition_id
    _kc = kafka_client

    _metrics_reporter = consume metrics_reporter
    _listen = listen
    _notify = consume notify

    _layout_initializer = layout_initializer
    _router_registry = router_registry

    _route_builder = route_builder
    for (target_worker_name, builder) in outgoing_boundary_builders.pairs() do
      let new_boundary =
        builder.build_and_initialize(_step_id_gen(), _layout_initializer)
      router_registry.register_disposable(new_boundary)
      _outgoing_boundaries(target_worker_name) = new_boundary
    end

    for consumer in routes.values() do
      _routes(consumer) =
        _route_builder(this, consumer, _metrics_reporter)
    end

    for (worker, boundary) in _outgoing_boundaries.pairs() do
      _routes(boundary) =
        _route_builder(this, boundary, _metrics_reporter)
    end

    _notify.update_boundaries(_outgoing_boundaries)

    match default_target
    | let r: Consumer =>
      match forward_route_builder
      | let frb: RouteBuilder =>
        _routes(r) = frb(this, r, _metrics_reporter)
      end
    end

    for r in _routes.values() do
      // TODO: this is a hack, we shouldn't be calling application events
      // directly. route lifecycle needs to be broken out better from
      // application lifecycle
      r.application_created()
    end

    for r in _routes.values() do
      r.application_initialized("KafkaSource-" + topic + "-"
        + partition_id.string())
    end

    _mute()

  be update_router(router: Router) =>
    let new_router =
      match router
      | let pr: PartitionRouter =>
        pr.update_boundaries(_outgoing_boundaries)
      | let spr: StatelessPartitionRouter =>
        spr.update_boundaries(_outgoing_boundaries)
      else
        router
      end
    _notify.update_router(new_router)

  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  =>
    """
    Build a new boundary for each builder that corresponds to a worker we
    don't yet have a boundary to. Each KafkaSource has its own
    OutgoingBoundary to each worker to allow for higher throughput.
    """
    for (target_worker_name, builder) in boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        let boundary = builder.build_and_initialize(_step_id_gen(),
          _layout_initializer)
        _outgoing_boundaries(target_worker_name) = boundary
        _router_registry.register_disposable(boundary)
        _routes(boundary) =
          _route_builder(this, boundary, _metrics_reporter)
      end
    end
    _notify.update_boundaries(_outgoing_boundaries)

  be reconnect_boundary(target_worker_name: String) =>
    try
      _outgoing_boundaries(target_worker_name)?.reconnect()
    else
      Fail()
    end

  be remove_route_for(step: Consumer) =>
    try
      _routes.remove(step)?
    else
      Fail()
    end

  //////////////
  // ORIGIN (resilience)
  be request_ack() =>
    None

  fun ref _acker(): Acker =>
    // TODO: we don't really need this
    // Because we dont actually do any resilience work
    Acker

  // Override these for KafkaSource as we are currently
  // not resilient.
  fun ref flush(low_watermark: U64) =>
    None

  be log_flushed(low_watermark: SeqId) =>
    None

  fun ref bookkeeping(o_route_id: RouteId, o_seq_id: SeqId) =>
    None

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    ifdef debug then
      @printf[I32]("KafkaSource received update_watermark\n".cstring())
    end

  fun ref _update_watermark(route_id: RouteId, seq_id: SeqId) =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    try
      _routes(c)?
    else
      None
    end

  fun ref next_sequence_id(): SeqId =>
    _seq_id = _seq_id + 1

  fun ref current_sequence_id(): SeqId =>
    _seq_id

  fun ref _mute() =>
    ifdef debug then
      @printf[I32]("Muting KafkaSource\n".cstring())
    end
    _kc.consumer_pause(_topic, _partition_id)

    _muted = true

  fun ref _unmute() =>
    ifdef debug then
      @printf[I32]("Muting KafkaSource\n".cstring())
    end
    _kc.consumer_resume(_topic, _partition_id)

    _muted = false

  be mute(c: Consumer) =>
    _muted_downstream.set(c)
    _mute()

  be unmute(c: Consumer) =>
    _muted_downstream.unset(c)

    if _muted_downstream.size() == 0 then
      _unmute()
    end

  fun ref is_muted(): Bool =>
    _muted

  be receive_kafka_message(msg: KafkaMessage val,
    network_received_timestamp: U64)
  =>
    if (msg.get_topic() != _topic)
      or (msg.get_partition_id() != _partition_id) then
      @printf[I32](("Msg topic: " + msg.get_topic() + " != _topic: " + _topic
        + " or Msg partition: " + msg.get_partition_id().string() + " != "
        + " _partition_id: " + _partition_id.string() + "!").cstring())
      Fail()
    end
    _notify.received(this, msg, network_received_timestamp)

  be dispose() =>
    @printf[I32]("Shutting down KafkaSource\n".cstring())

    for b in _outgoing_boundaries.values() do
      b.dispose()
    end

    _kc.dispose()
