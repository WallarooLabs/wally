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
use "net"
use "pony-kafka"
use "pony-kafka/customlogger"
use "time"
use "wallaroo/core/common"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"


actor KafkaSink is (Consumer & KafkaClientManager & KafkaProducer)
  // Steplike
  let _encoder: KafkaEncoderWrapper
  let _wb: Writer = Writer
  let _metrics_reporter: MetricsReporter
  var _initializer: (LocalTopologyInitializer | None) = None

  // Consumer
  var _upstreams: SetIs[Producer] = _upstreams.create()
  var _mute_outstanding: Bool = false

  var _kc: (KafkaClient tag | None) = None
  let _conf: KafkaConfig val
  let _auth: TCPConnectionAuth

  // Producer (Resilience)
  let _terminus_route: TerminusRoute = TerminusRoute

  // variable to hold producer mapping for sending requests to broker
  //  connections
  var _kafka_producer_mapping: (KafkaProducerMapping ref | None) = None

  var _ready_to_produce: Bool = false
  var _application_initialized: Bool = false

  let _topic: String

  // Items in tuple are: metric_name, metrics_id, send_ts, worker_ingress_ts,
  //   pipeline_time_spent, tracking_id
  let _pending_delivery_report: MapIs[Any tag, (String, U16, U64, U64, U64,
    (U64 | None))] = _pending_delivery_report.create()

  new create(encoder_wrapper: KafkaEncoderWrapper,
    metrics_reporter: MetricsReporter iso, conf: KafkaConfig val,
    auth: TCPConnectionAuth)
  =>
    _encoder = encoder_wrapper
    _metrics_reporter = consume metrics_reporter
    _conf = conf
    _auth = auth

    _topic = try
               _conf.topics.keys().next()?
             else
               Fail()
               ""
             end

  fun ref update_producer_mapping(mapping: KafkaProducerMapping):
    (KafkaProducerMapping | None)
  =>
    _kafka_producer_mapping = mapping

  fun ref producer_mapping(): (KafkaProducerMapping | None) =>
    _kafka_producer_mapping

  be kafka_client_error(error_report: KafkaErrorReport) =>
    @printf[I32](("ERROR: Kafka client encountered an unrecoverable error! " +
      error_report.string() + "\n").cstring())

    Fail()

  be receive_kafka_topics_partitions(new_topic_partitions: Map[String,
    (KafkaTopicType, Set[I32])] val)
  =>
    None

  be kafka_producer_ready() =>
    _ready_to_produce = true

    // we either signal back to intializer that we're ready to work here or in
    //  application_ready_to_work depending on which one is called second.
    if _application_initialized then
      match _initializer
      | let initializer: LocalTopologyInitializer =>
        initializer.report_ready_to_work(this)
        _initializer = None
      else
        // kafka_producer_ready should never be called twice
        Fail()
      end

      _unmute_upstreams()
    end

  be kafka_message_delivery_report(delivery_report: KafkaProducerDeliveryReport)
  =>
    try
      if not _pending_delivery_report.contains(delivery_report.opaque) then
        @printf[I32](("Kafka Sink: Error kafka delivery report opaque doesn't"
          + " exist in _pending_delivery_report\n").cstring())
        error
      end

      (_, (let metric_name, let metrics_id, let send_ts, let worker_ingress_ts,
        let pipeline_time_spent, let tracking_id)) =
        _pending_delivery_report.remove(delivery_report.opaque)?

      if delivery_report.status isnt ErrorNone then
        @printf[I32](("Kafka Sink: Error reported in kafka delivery report: "
          + delivery_report.status.string() + "\n").cstring())
        error
      end

      ifdef "resilience" then
        match tracking_id
        | let sent: SeqId =>
          _terminus_route.receive_ack(sent)
        end
      end

      let end_ts = Time.nanos()
      _metrics_reporter.step_metric(metric_name, "Kafka send time", metrics_id,
        send_ts, end_ts)

      let final_ts = Time.nanos()
      let time_spent = final_ts - worker_ingress_ts

      ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(metric_name, "Before end at sink", 9999,
          end_ts, final_ts)
      end

      _metrics_reporter.pipeline_metric(metric_name,
        time_spent + pipeline_time_spent)
      _metrics_reporter.worker_metric(metric_name, time_spent)
    else
      // TODO: How are we supposed to handle errors?
      @printf[I32]("Error handling kafka delivery report in Kakfa Sink\n"
        .cstring())
    end

  fun ref _kafka_producer_throttled(topic_mapping: Map[String, Map[I32, I32]]
    val)
  =>
    if not _mute_outstanding then
      _mute_upstreams()
    end

  fun ref _kafka_producer_unthrottled(topic_mapping: Map[String, Map[I32, I32]]
    val, fully_unthrottled: Bool)
  =>
    if fully_unthrottled and _mute_outstanding then
      _unmute_upstreams()
    end

  fun ref _mute_upstreams() =>
    for u in _upstreams.values() do
      u.mute(this)
    end
    _mute_outstanding = true

  fun ref _unmute_upstreams() =>
    for u in _upstreams.values() do
      u.unmute(this)
    end
    _mute_outstanding = false

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    _initializer = initializer
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter)
  =>
    _mute_upstreams()

    initializer.report_initialized(this)

    // create kafka client
    let kc = KafkaClient(_auth, _conf, this)
    _kc = kc
    kc.register_producer(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    _application_initialized = true

    if _ready_to_produce then
      initializer.report_ready_to_work(this)
      _initializer = None

      _unmute_upstreams()
    end

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be request_ack() =>
    _terminus_route.request_ack()

  fun ref _next_tracking_id(i_producer: Producer, i_route_id: RouteId,
    i_seq_id: SeqId): (U64 | None)
  =>
    ifdef "resilience" then
      return _terminus_route.terminate(i_producer, i_route_id, i_seq_id)
    end

    None

  be register_producer(producer: Producer) =>
    _upstreams.set(producer)

  be unregister_producer(producer: Producer) =>
    ifdef debug then
      Invariant(_upstreams.contains(producer))
    end

    _upstreams.unset(producer)

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    var my_latest_ts: U64 = latest_ts
    var my_metrics_id = ifdef "detailed-metrics" then
      my_latest_ts = Time.nanos()
      _metrics_reporter.step_metric(metric_name, "Before receive at sink",
        metrics_id, latest_ts, my_latest_ts)
        metrics_id + 1
      else
        metrics_id
      end


    ifdef "trace" then
      @printf[I32]("Rcvd msg at KafkaSink\n".cstring())
    end
    try
      (let encoded_value, let encoded_key) = _encoder.encode[D](data, _wb)?
      my_metrics_id = ifdef "detailed-metrics" then
          var old_ts = my_latest_ts = Time.nanos()
          _metrics_reporter.step_metric(metric_name, "Sink encoding time", 9998,
          old_ts, my_latest_ts)
          metrics_id + 1
        else
          metrics_id
        end

      try
        // `any` is required because if `data` is used directly, there are
        // issues with the items not being found in `_pending_delivery_report`.
        let any: Any tag = data
        let ret = (_kafka_producer_mapping as KafkaProducerMapping ref)
          .send_topic_message(_topic, any, encoded_value, encoded_key)

        // TODO: Proper error handling
        if ret isnt None then error end

        let next_tracking_id = _next_tracking_id(i_producer, i_route_id, i_seq_id)
        _pending_delivery_report(any) = (metric_name, my_metrics_id,
          my_latest_ts, worker_ingress_ts, pipeline_time_spent,
          next_tracking_id)
      else
        // TODO: How are we supposed to handle errors?
        @printf[I32]("Error sending message to Kafka via Kakfa Sink\n"
          .cstring())
      end

    else
      Fail()
    end

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    // TODO: implement this once state save/recover is handled
    Fail()

  be receive_state(state: ByteSeq val) =>
    // TODO: implement state recovery
    Fail()

  be dispose() =>
    @printf[I32]("Shutting down KafkaSink\n".cstring())
    try
      (_kc as KafkaClient tag).dispose()
    end
