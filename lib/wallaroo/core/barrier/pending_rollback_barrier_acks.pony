/*

Copyright 2018 The Wallaroo Authors.

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

use "wallaroo/core/common"
use "wallaroo/core/sink"


class PendingRollbackBarrierAcks
  // We only want to keep acks for the latest rollback token.
  var latest_rollback_token: CheckpointRollbackBarrierToken =
    CheckpointRollbackBarrierToken(0, 0)

  let barrier_acks: Array[(Sink, CheckpointRollbackBarrierToken)] =
    barrier_acks.create()
  let worker_barrier_start_acks:
    Array[(WorkerName, CheckpointRollbackBarrierToken)] =
      worker_barrier_start_acks.create()
  let worker_barrier_acks: Array[(WorkerName, CheckpointRollbackBarrierToken)] =
    worker_barrier_acks.create()

  fun ref ack_barrier(s: Sink, barrier_token: CheckpointRollbackBarrierToken)
  =>
    if barrier_token > latest_rollback_token then
      latest_rollback_token = barrier_token
      clear()
    end
    barrier_acks.push((s, barrier_token))

  fun ref worker_ack_barrier_start(w: WorkerName,
    barrier_token: CheckpointRollbackBarrierToken)
  =>
    if barrier_token > latest_rollback_token then
      latest_rollback_token = barrier_token
      clear()
    end
    worker_barrier_start_acks.push((w, barrier_token))

  fun ref worker_ack_barrier(w: WorkerName,
    barrier_token: CheckpointRollbackBarrierToken)
  =>
    if barrier_token > latest_rollback_token then
      latest_rollback_token = barrier_token
      clear()
    end
    worker_barrier_acks.push((w, barrier_token))

  fun ref flush(token: BarrierToken, ab: ActiveBarriers) =>
    if token == latest_rollback_token then
      for (r, t) in barrier_acks.values() do
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
      match token
      | let srbt: CheckpointRollbackBarrierToken =>
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
