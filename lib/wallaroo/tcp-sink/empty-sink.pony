use "collections"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/topology"

actor EmptySink is CreditFlowConsumerStep
  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Producer, msg_uid: U128,
    frac_ids: None, seq_id: SeqId, route_id: RouteId)
  =>
    ifdef "trace" then
      @printf[I32]("Rcvd msg at EmptySink\n".cstring())
    end
    None

  be replay_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    origin: Producer, msg_uid: U128,
    frac_ids: None, incoming_seq_id: SeqId, route_id: RouteId)
  =>
    None

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    omni_router: OmniRouter val)
  =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be register_producer(producer: Producer) =>
    None

  be unregister_producer(producer: Producer, credits_returned: ISize) =>
    None

  be credit_request(from: Producer) =>
    None

  be return_credits(credits: ISize) =>
    None
