
use "collections"
use "wallaroo/core/barrier"
use "wallaroo/core/common"
use "wallaroo/core/topology"

primitive StepTestSender[V: (Hashable & Equatable[V] val)]
  fun send_seq(step: Step, inputs: Array[V] val, producer_id: RoutingId,
    producer: Producer)
  =>
    for input in inputs.values() do
      send(step, input, producer_id, producer)
    end

  fun send(step: Step, input: V, producer_id: RoutingId, producer: Producer) =>
    step.run[V]("", 1, input, "", 1, 1, producer_id, producer, 1, None, 1, 1,
      1, 1)

  fun send_barrier(step: Step, token: BarrierToken, producer_id: RoutingId,
    producer: Producer)
  =>
    step.receive_barrier(producer_id, producer, token)
