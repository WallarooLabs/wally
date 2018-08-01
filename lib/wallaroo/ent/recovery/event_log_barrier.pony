

use "wallaroo/core/common"
use "wallaroo/ent/barrier"


type LogRotationId is U64

class val LogRotationBarrierToken is BarrierToken
  let id: LogRotationId
  let worker: WorkerName

  new val create(id': LogRotationId, w: WorkerName) =>
    id = id'
    worker = w

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let lbt: LogRotationBarrierToken =>
      (id == lbt.id) and (worker == lbt.worker)
    else
      false
    end

  fun hash(): USize =>
    0

  fun lt(that: box->BarrierToken): Bool =>
    match that
    | let lbt: LogRotationBarrierToken =>
      if id == lbt.id then
        worker < lbt.worker
      else
        id < lbt.id
      end
    else
      false
    end

  fun gt(that: box->BarrierToken): Bool =>
    match that
    | let lbt: LogRotationBarrierToken =>
      if id == lbt.id then
        worker > lbt.worker
      else
        id > lbt.id
      end
    else
      false
    end

  fun string(): String =>
    "LogRotationBarrierToken(" + worker + "->" + id.string() + ")"

class val LogRotationResumeBarrierToken is BarrierToken
  let id: LogRotationId
  let worker: WorkerName

  new val create(id': LogRotationId, w: WorkerName) =>
    id = id'
    worker = w

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let lbt: LogRotationResumeBarrierToken =>
      (id == lbt.id) and (worker == lbt.worker)
    else
      false
    end

  fun hash(): USize =>
    0

  fun lt(that: box->BarrierToken): Bool =>
    match that
    | let lbt: LogRotationResumeBarrierToken =>
      if id == lbt.id then
        worker < lbt.worker
      else
        id < lbt.id
      end
    else
      false
    end

  fun gt(that: box->BarrierToken): Bool =>
    match that
    | let lbt: LogRotationResumeBarrierToken =>
      if id == lbt.id then
        worker > lbt.worker
      else
        id > lbt.id
      end
    else
      false
    end

  fun string(): String =>
    "LogRotationResumeBarrierToken(" + worker + "->" + id.string() + ")"
