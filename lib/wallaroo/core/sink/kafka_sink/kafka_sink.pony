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
use "wallaroo/core/sink"
use "wallaroo/ent/recovery"
use "wallaroo/ent/snapshot"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/topology"


actor KafkaSink is (Sink & KafkaClientManager & KafkaProducer)
  // Steplike
  let _name: String
  var _message_processor: SinkMessageProcessor = EmptySinkMessageProcessor
  let _sink_id: StepId
  let _event_log: EventLog
  var _recovering: Bool
  let _encoder: KafkaEncoderWrapper
  let _wb: Writer = Writer
  let _metrics_reporter: MetricsReporter
  var _initializer: (LocalTopologyInitializer | None) = None
  let _snapshot_initiator: SnapshotInitiator

  // Consumer
  var _upstreams: SetIs[Producer] = _upstreams.create()
  // _inputs keeps track of all inputs by step id. There might be
  // duplicate producers in this map (unlike upstreams) since there might be
  // multiple upstream step ids over a boundary
  let _inputs: Map[StepId, Producer] = _inputs.create()
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

  new create(sink_id: StepId, name: String, event_log: EventLog,
    recovering: Bool, encoder_wrapper: KafkaEncoderWrapper,
    metrics_reporter: MetricsReporter iso, conf: KafkaConfig val,
    snapshot_initiator: SnapshotInitiator, auth: TCPConnectionAuth)
  =>
    _name = name
    _recovering = recovering
    _sink_id = sink_id
    _event_log = event_log
    _encoder = encoder_wrapper
    _metrics_reporter = consume metrics_reporter
    _conf = conf
    _snapshot_initiator = snapshot_initiator
    _auth = auth

    _topic = try
               _conf.topics.keys().next()?
             else
               Fail()
               ""
             end

    _message_processor = NormalSinkMessageProcessor(this)

    // register resilient with event log
    _event_log.register_resilient(this, _sink_id)

  fun ref create_producer_mapping(client: KafkaClient, mapping: KafkaProducerMapping):
    (KafkaProducerMapping | None)
  =>
    _kafka_producer_mapping = mapping

  fun ref producer_mapping(client: KafkaClient): (KafkaProducerMapping | None) =>
    _kafka_producer_mapping

  be kafka_client_error(client: KafkaClient, error_report: KafkaErrorReport) =>
    @printf[I32](("ERROR: Kafka client encountered an unrecoverable error! " +
      error_report.string() + "\n").cstring())

    Fail()

  be receive_kafka_topics_partitions(client: KafkaClient, new_topic_partitions: Map[String,
    (KafkaTopicType, Set[KafkaPartitionId])] val)
  =>
    None

  be kafka_producer_ready(client: KafkaClient) =>
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

      if _mute_outstanding and not _recovering then
        _unmute_upstreams()
      end
    end

  be kafka_message_delivery_report(client: KafkaClient, delivery_report: KafkaProducerDeliveryReport)
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

      // TODO: Resilience: log_flushed here to update low watermark for recovery?

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

  fun ref _kafka_producer_throttled(client: KafkaClient, topic_partitions_throttled: Map[String, Set[KafkaPartitionId]] val)
  =>
    if not _mute_outstanding then
      _mute_upstreams()
    end

  fun ref _kafka_producer_unthrottled(client: KafkaClient, topic_partitions_throttled: Map[String, Set[KafkaPartitionId]] val)
  =>
    if (topic_partitions_throttled.size() == 0) and _mute_outstanding then
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
    target_id_router: TargetIdRouter)
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

      if _mute_outstanding and not _recovering then
        _unmute_upstreams()
      end
    end

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be request_ack() =>
    ifdef "trace" then
      @printf[I32]("request_ack in %s\n".cstring(), _name.cstring())
    end

    _terminus_route.request_ack()

  fun ref _next_tracking_id(i_producer: Producer, i_route_id: RouteId,
    i_seq_id: SeqId): (U64 | None)
  =>
    ifdef "resilience" then
      return _terminus_route.terminate(i_producer, i_route_id, i_seq_id)
    end

    None

  be register_producer(id: StepId, producer: Producer) =>
    @printf[I32]("!@ Registered producer %s at sink %s. Total %s upstreams.\n".cstring(), id.string().cstring(), _sink_id.string().cstring(), _upstreams.size().string().cstring())
    // If we have at least one input, then we are involved in snapshotting.
    if _inputs.size() == 0 then
      _snapshot_initiator.register_sink(this)
    end

    _inputs(id) = producer
    _upstreams.set(producer)

  be unregister_producer(id: StepId, producer: Producer) =>
    @printf[I32]("!@ Unregistered producer %s at sink %s. Total %s upstreams.\n".cstring(), id.string().cstring(), _sink_id.string().cstring(), _upstreams.size().string().cstring())

    ifdef debug then
      Invariant(_upstreams.contains(producer))
    end

    if _inputs.contains(id) then
      try
        _inputs.remove(id)?
      else
        Fail()
      end

      var have_input = false
      for i in _inputs.values() do
        if i is producer then have_input = true end
      end
      if not have_input then
        _upstreams.unset(producer)
      end

      // If we have no inputs, then we are not involved in snapshotting.
      if _inputs.size() == 0 then
        _snapshot_initiator.unregister_sink(this)
      end
    end

  be report_status(code: ReportStatusCode) =>
    None

  be request_in_flight_ack(request_id: RequestId, requester_id: StepId,
    requester: InFlightAckRequester)
  =>
    requester.receive_in_flight_ack(request_id)

  be request_in_flight_resume_ack(in_flight_resume_ack_id: InFlightResumeAckId,
    request_id: RequestId, requester_id: StepId,
    requester: InFlightAckRequester, leaving_workers: Array[String] val)
  =>
    requester.receive_in_flight_resume_ack(request_id)

  be try_finish_in_flight_request_early(requester_id: StepId) =>
    None

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_producer_id: StepId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _message_processor.process_message[D](metric_name, pipeline_time_spent,
      data, i_producer_id, i_producer, msg_uid, frac_ids, i_seq_id, i_route_id,
      latest_ts, metrics_id, worker_ingress_ts)

  fun ref process_message[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, i_producer_id: StepId,
    i_producer: Producer, msg_uid: MsgId, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId, latest_ts: U64, metrics_id: U16,
    worker_ingress_ts: U64)
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
      (let encoded_value, let encoded_key, let part_id) = _encoder.encode[D](data, _wb)?
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
        // This is mainly when `data` is a primitive where it will get automagically
        // boxed on message send and the `tag` for that boxed version of the primitive
        // will not match the when checked against the `_pending_delivery_report` map.
        let any: Any tag = data
        let ret = (_kafka_producer_mapping as KafkaProducerMapping ref)
          .send_topic_message(_topic, any, encoded_value, encoded_key where partition_id = part_id)

        // TODO: Proper error handling
        if ret isnt None then error end

        // TODO: Resilience: Write data to event log for recovery purposes

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
    data: D, i_producer_id: StepId, i_producer: Producer, msg_uid: MsgId,
    frac_ids: FractionalMessageId, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("replay_run in %s\n".cstring(), _name.cstring())
    end
    // TODO: implement this once state save/recover is handled
    Fail()

  be receive_state(state: ByteSeq val) =>
    ifdef "trace" then
      @printf[I32]("receive_state in %s\n".cstring(), _name.cstring())
    end
    // TODO: implement state recovery
    Fail()

  be log_replay_finished()
  =>
    ifdef "trace" then
      @printf[I32]("log_replay_finished in %s\n".cstring(), _name.cstring())
    end
    _recovering = false
    if _mute_outstanding then
      _unmute_upstreams()
    end

  be replay_log_entry(uid: U128, frac_ids: FractionalMessageId,
    statechange_id: U64, payload: ByteSeq)
  =>
    ifdef "trace" then
      @printf[I32]("replay_log_entry in %s\n".cstring(), _name.cstring())
    end
    // TODO: implement this for resilience/recovery
    Fail()

  be initialize_seq_id_on_recovery(seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32]("initialize_seq_id_on_recovery in %s\n".cstring(), _name.cstring())
    end
    // TODO: implement this for resilience/recovery
    Fail()

  ///////////////
  // SNAPSHOTS
  ///////////////
  be receive_snapshot_barrier(step_id: StepId, sr: SnapshotRequester,
    snapshot_id: SnapshotId)
  =>
    if _message_processor.snapshot_in_progress() then
      _message_processor.receive_snapshot_barrier(step_id, sr,
        snapshot_id)
    else
      match _message_processor
      | let nsmp: NormalSinkMessageProcessor =>
        let sr_inputs = recover iso Map[StepId, SnapshotRequester] end
        for (sr_id, i) in _inputs.pairs() do
          sr_inputs(sr_id) = i
        end
        _message_processor = SnapshotSinkMessageProcessor(this,
          SnapshotBarrierAcker(_sink_id, this, consume sr_inputs,
            _snapshot_initiator, snapshot_id))
      else
        Fail()
      end
    end

  be remote_snapshot_state() =>
    // Nothing to snapshot at this point
    None

  fun ref snapshot_state(snapshot_id: SnapshotId) =>
    // Nothing to snapshot at this point
    None

  fun ref snapshot_complete() =>
    ifdef debug then
      Invariant(_message_processor.snapshot_in_progress())
    end
    _message_processor.flush()
    _message_processor = NormalSinkMessageProcessor(this)


  be log_flushed(low_watermark: SeqId) =>
    ifdef "trace" then
      @printf[I32]("log_flushed in %s\n".cstring(), _name.cstring())
    end
    // TODO: implement this for resilience/recovery
    Fail()

  be dispose() =>
    @printf[I32]("Shutting down KafkaSink\n".cstring())
    try
      (_kc as KafkaClient tag).dispose()
    end
