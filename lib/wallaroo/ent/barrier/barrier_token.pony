/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/ent/in_flight_acking"
use "wallaroo/ent/snapshot"


trait val BarrierToken is (Hashable & Equatable[BarrierToken])
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

  fun string(): String =>
    "InitialBarrierToken"

class val InFlightAckBarrierToken is BarrierToken
  let _worker: String
  let _id: InFlightAckId

  new val create(worker': String, id': InFlightAckId) =>
    _worker = worker'
    _id = id'

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let ifa: InFlightAckBarrierToken =>
      (_id == ifa._id) and (_worker == ifa._worker)
    else
      false
    end

  fun hash(): USize =>
    _id.hash() xor _worker.hash()

  fun id(): InFlightAckId =>
    _id

  fun string(): String =>
    "InFlightAckBarrierToken(" + _worker + ", " + _id.string() + ")"

class val InFlightAckResumeBarrierToken is BarrierToken
  let _worker: String
  let _id: InFlightAckId

  new val create(worker': String, id': InFlightAckId) =>
    _worker = worker'
    _id = id'

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let ifa: InFlightAckResumeBarrierToken =>
      (_id == ifa._id) and (_worker == ifa._worker)
    else
      false
    end

  fun hash(): USize =>
    _id.hash() xor _worker.hash()

  fun id(): InFlightAckId =>
    _id

  fun string(): String =>
    "InFlightAckResumeBarrierToken(" + _worker + ", " + _id.string() + ")"

class val SnapshotBarrierToken is BarrierToken
  let id: SnapshotId

  new val create(id': SnapshotId) =>
    id = id'

  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let sbt: SnapshotBarrierToken =>
      id == sbt.id
    else
      false
    end

  fun hash(): USize =>
    id.hash()

  fun string(): String =>
    "SnapshotBarrierToken(" + id.string() + ")"

