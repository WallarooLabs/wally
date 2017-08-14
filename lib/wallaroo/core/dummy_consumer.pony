use "collections"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/routing"
use "wallaroo/topology"


actor DummyConsumer is Consumer
  be register_producer(producer: Producer) =>
    None

  be unregister_producer(producer: Producer) =>
    None

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_origin: Producer, msg_uid: U128, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    None

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_origin: Producer, msg_uid: U128, frac_ids: FractionalMessageId,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    None

  be receive_state(state: ByteSeq val) =>
    None

  be request_ack() =>
    None

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    None

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter val)
  =>
    None

  be application_initialized(initializer: LocalTopologyInitializer) =>
    None

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None
