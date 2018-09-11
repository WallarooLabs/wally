
use "wallaroo/core/common"


class PendingRollbackBarrierAcks
  // We only want to keep acks for the latest rollback token.
  var latest_rollback_token: SnapshotRollbackBarrierToken =
    SnapshotRollbackBarrierToken(0, 0)

  let barrier_acks: Array[(BarrierReceiver, SnapshotRollbackBarrierToken)] =
    barrier_acks.create()
  let worker_barrier_start_acks:
    Array[(WorkerName, SnapshotRollbackBarrierToken)] =
      worker_barrier_start_acks.create()
  let worker_barrier_acks: Array[(WorkerName, SnapshotRollbackBarrierToken)] =
    worker_barrier_acks.create()

  fun ref ack_barrier(s: BarrierReceiver,
    barrier_token: SnapshotRollbackBarrierToken)
  =>
    if barrier_token > latest_rollback_token then
      latest_rollback_token = barrier_token
      clear()
    end
    barrier_acks.push((s, barrier_token))

  fun ref worker_ack_barrier_start(w: WorkerName,
    barrier_token: SnapshotRollbackBarrierToken)
  =>
    if barrier_token > latest_rollback_token then
      latest_rollback_token = barrier_token
      clear()
    end
    worker_barrier_start_acks.push((w, barrier_token))

  fun ref worker_ack_barrier(w: WorkerName,
    barrier_token: SnapshotRollbackBarrierToken)
  =>
    if barrier_token > latest_rollback_token then
      latest_rollback_token = barrier_token
      clear()
    end
    worker_barrier_acks.push((w, barrier_token))

  fun ref flush(token: BarrierToken, ab: ActiveBarriers) =>
    if token == latest_rollback_token then
      for (r, t) in barrier_acks.values() do
        @printf[I32]("!@ -- Flushing ack for %s\n".cstring(), t.string().cstring())
        ab.ack_barrier(r, t)
      end
      for (w, t) in worker_barrier_start_acks.values() do
        ab.worker_ack_barrier_start(w, t)
      end
      for (w, t) in worker_barrier_acks.values() do
        ab.worker_ack_barrier(w, t)
      end
      clear()
    else
      @printf[I32]("!@ PendingRollbackBarrierAcks: Flushing but acks are outdated.\n".cstring())
      match token
      | let srbt: SnapshotRollbackBarrierToken =>
        if srbt > latest_rollback_token then
          clear()
          latest_rollback_token = srbt
        end
      end
    end

  fun ref clear() =>
    barrier_acks.clear()
    worker_barrier_start_acks.clear()
    worker_barrier_acks.clear()
