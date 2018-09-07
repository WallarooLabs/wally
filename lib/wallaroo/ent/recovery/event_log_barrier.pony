/*

Copyright 2018 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

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
