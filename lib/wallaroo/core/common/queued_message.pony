trait val QueuedMessage
  fun process_message(consumer: Consumer ref)

class val TypedQueuedMessage[D: Any val] is QueuedMessage
  let metric_name: String
  let pipeline_time_spent: U64
  let data: D
  let i_producer_id: RoutingId
  let i_producer: Producer
  let msg_uid: MsgId
  let frac_ids: FractionalMessageId
  let i_seq_id: SeqId
  let i_route_id: RouteId
  let latest_ts: U64
  let metrics_id: U16
  let worker_ingress_ts: U64

  new val create(metric_name': String, pipeline_time_spent': U64,
    data': D, i_producer_id': RoutingId, i_producer': Producer, msg_uid': MsgId,
    frac_ids': FractionalMessageId, i_seq_id': SeqId, i_route_id': RouteId,
    latest_ts': U64, metrics_id': U16, worker_ingress_ts': U64)
  =>
    metric_name = metric_name'
    pipeline_time_spent = pipeline_time_spent'
    data = data'
    i_producer_id = i_producer_id'
    i_producer = i_producer'
    msg_uid = msg_uid'
    frac_ids = frac_ids'
    i_seq_id = i_seq_id'
    i_route_id = i_route_id'
    latest_ts = latest_ts'
    metrics_id = metrics_id'
    worker_ingress_ts = worker_ingress_ts'

  fun process_message(consumer: Consumer ref) =>
    consumer.process_message[D](metric_name, pipeline_time_spent, data,
      i_producer_id, i_producer, msg_uid, frac_ids, i_seq_id, i_route_id,
      latest_ts, metrics_id, worker_ingress_ts)
