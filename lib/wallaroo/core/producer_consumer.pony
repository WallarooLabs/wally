use "collections"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/routing"
use "wallaroo/topology"

trait tag Producer is (Mutable & Ackable & AckRequester)
  fun ref route_to(c: Consumer): (Route | None)
  fun ref next_sequence_id(): SeqId
  fun ref current_sequence_id(): SeqId

trait tag Consumer is (Runnable & StateReceiver & AckRequester & Initializable)
  be register_producer(producer: Producer)
  be unregister_producer(producer: Producer)

trait tag Runnable
  be run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    i_origin: Producer, msg_uid: U128,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, i_origin: Producer, msg_uid: U128,
    i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)

trait tag Mutable
  be mute(c: Consumer)
  be unmute(c: Consumer)

trait tag StateReceiver
  be receive_state(state: ByteSeq val)

trait tag AckRequester
  be request_ack()

trait tag Initializable
  be application_begin_reporting(initializer: LocalTopologyInitializer)
  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter val)

  be application_initialized(initializer: LocalTopologyInitializer)
  be application_ready_to_work(initializer: LocalTopologyInitializer)
