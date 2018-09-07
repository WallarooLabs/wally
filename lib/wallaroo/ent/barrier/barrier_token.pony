/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/ent/autoscale"
use "wallaroo/ent/checkpoint"
use "wallaroo_labs/partial_order"


trait val BarrierToken is (Hashable & Equatable[BarrierToken] &
  PartialComparable[BarrierToken])
  fun string(): String

primitive InitialBarrierToken is BarrierToken
  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let ifa: InitialBarrierToken =>
      true
    else
      false
    end

  fun hash(): USize => 0

  fun lt(that: box->BarrierToken): Bool =>
    false
  fun gt(that: box->BarrierToken): Bool =>
    false

  fun string(): String =>
    "InitialBarrierToken"

class val AutoscaleBarrierToken is BarrierToken
  let _worker: String
  let _id: AutoscaleId

  new val create(worker': String, id': AutoscaleId) =>
    _worker = worker'
    _id = id'

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let ifa: AutoscaleBarrierToken =>
      (_id == ifa._id) and (_worker == ifa._worker)
    else
      false
    end

  fun hash(): USize =>
    _id.hash() xor _worker.hash()

  fun id(): AutoscaleId =>
    _id

  fun lt(that: box->BarrierToken): Bool =>
    match that
    | let abt: AutoscaleBarrierToken =>
      if _id == abt._id then
        _worker < abt._worker
      else
        _id < abt._id
      end
    else
      false
    end

  fun gt(that: box->BarrierToken): Bool =>
    match that
    | let abt: AutoscaleBarrierToken =>
      if _id == abt._id then
        _worker > abt._worker
      else
        _id > abt._id
      end
    else
      false
    end

  fun string(): String =>
    "AutoscaleBarrierToken(" + _worker + ", " + _id.string() + ")"

class val AutoscaleResumeBarrierToken is BarrierToken
  let _worker: String
  let _id: AutoscaleId

  new val create(worker': String, id': AutoscaleId) =>
    _worker = worker'
    _id = id'

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let ifa: AutoscaleResumeBarrierToken =>
      (_id == ifa._id) and (_worker == ifa._worker)
    else
      false
    end

  fun hash(): USize =>
    _id.hash() xor _worker.hash()

  fun id(): AutoscaleId =>
    _id

  fun lt(that: box->BarrierToken): Bool =>
    match that
    | let abt: AutoscaleResumeBarrierToken =>
      if _id == abt._id then
        _worker < abt._worker
      else
        _id < abt._id
      end
    else
      false
    end

  fun gt(that: box->BarrierToken): Bool =>
    match that
    | let abt: AutoscaleResumeBarrierToken =>
      if _id == abt._id then
        _worker > abt._worker
      else
        _id > abt._id
      end
    else
      false
    end

  fun string(): String =>
    "AutoscaleResumeBarrierToken(" + _worker + ", " + _id.string() + ")"

class val CheckpointBarrierToken is BarrierToken
  let id: CheckpointId

  new val create(id': CheckpointId) =>
    id = id'

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let sbt: CheckpointBarrierToken =>
      id == sbt.id
    else
      false
    end

  fun hash(): USize =>
    id.hash()

  fun lt(that: box->BarrierToken): Bool =>
    match that
    | let sbt: CheckpointBarrierToken =>
      id < sbt.id
    else
      false
    end

  fun gt(that: box->BarrierToken): Bool =>
    match that
    | let sbt: CheckpointBarrierToken =>
      id > sbt.id
    else
      false
    end

  fun string(): String =>
    "CheckpointBarrierToken(" + id.string() + ")"

class val CheckpointRollbackBarrierToken is BarrierToken
  let rollback_id: RollbackId
  let checkpoint_id: CheckpointId

  new val create(rollback_id': RollbackId, checkpoint_id': CheckpointId) =>
    rollback_id = rollback_id'
    checkpoint_id = checkpoint_id'

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let sbt: CheckpointRollbackBarrierToken =>
      (checkpoint_id == sbt.checkpoint_id) and (rollback_id == sbt.rollback_id)
    else
      false
    end

  fun hash(): USize =>
    rollback_id.hash() xor checkpoint_id.hash()

  fun lt(that: box->BarrierToken): Bool =>
    match that
    | let sbt: CheckpointRollbackBarrierToken =>
      rollback_id < sbt.rollback_id
    | let srbt: CheckpointRollbackResumeBarrierToken =>
      rollback_id <= srbt.rollback_id
    else
      false
    end

  fun gt(that: box->BarrierToken): Bool =>
    match that
    | let sbt: CheckpointRollbackBarrierToken =>
      rollback_id > sbt.rollback_id
    | let srbt: CheckpointRollbackResumeBarrierToken =>
      rollback_id > srbt.rollback_id
    else
      // A Rollback token is greater than any non-rollback token since it
      // always takes precedence.
      true
    end

  fun string(): String =>
    "CheckpointRollbackBarrierToken(Rollback " + rollback_id.string() +
      ", Checkpoint " + checkpoint_id.string() + ")"

class val CheckpointRollbackResumeBarrierToken is BarrierToken
  let rollback_id: RollbackId
  let checkpoint_id: CheckpointId

  new val create(rollback_id': RollbackId, checkpoint_id': CheckpointId) =>
    rollback_id = rollback_id'
    checkpoint_id = checkpoint_id'

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let sbt: CheckpointRollbackResumeBarrierToken =>
      (checkpoint_id == sbt.checkpoint_id) and (rollback_id == sbt.rollback_id)
    else
      false
    end

  fun hash(): USize =>
    rollback_id.hash() xor checkpoint_id.hash()

  fun lt(that: box->BarrierToken): Bool =>
    match that
    | let sbt: CheckpointRollbackResumeBarrierToken =>
      rollback_id < sbt.rollback_id
    else
      false
    end

  fun gt(that: box->BarrierToken): Bool =>
    match that
    | let srbt: CheckpointRollbackResumeBarrierToken =>
      rollback_id > srbt.rollback_id
    | let sbt: CheckpointRollbackBarrierToken =>
      rollback_id >= sbt.rollback_id
    else
      // A Rollback token is greater than any non-rollback token since it
      // always takes precedence.
      true
    end

  fun string(): String =>
    "CheckpointRollbackResumeBarrierToken(Rollback " + rollback_id.string() + ", Checkpoint " + checkpoint_id.string() + ")"
