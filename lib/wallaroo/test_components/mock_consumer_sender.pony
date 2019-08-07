use "collections"
use "ponytest"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/messages"


class MockConsumerSender[V: Any val] is TestableConsumerSender
  let _h: TestHelper
  let outputs: Array[V] = outputs.create()
  let forwarded: Array[DeliveryMsg] = forwarded.create()
  let registered_at: SetIs[RoutingId] = registered_at.create()

  new create(h: TestHelper) =>
    _h = h

  fun ref send[D: Any val](metric_name: String,
    pipeline_time_spent: U64, data: D, key: Key, event_ts: U64,
    watermark_ts: U64, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64,
    consumer: Consumer)
  =>
    match data
    | let v: V =>
      outputs.push(v)
    else
      _h.fail("ConsumerSender was sent data of wrong type.")
    end

  fun ref forward(delivery_msg: DeliveryMsg, pipeline_time_spent: U64,
    latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64, boundary: OutgoingBoundary)
  =>
    forwarded.push(delivery_msg)

  fun ref register_producer(consumer_id: RoutingId, consumer: Consumer) =>
    registered_at.set(consumer_id)

  fun ref unregister_producer(consumer_id: RoutingId, consumer: Consumer) =>
    registered_at.unset(consumer_id)

  fun ref update_output_watermark(w: U64): (U64, U64) =>
    (0, 0)

  fun producer_id(): RoutingId =>
    0
