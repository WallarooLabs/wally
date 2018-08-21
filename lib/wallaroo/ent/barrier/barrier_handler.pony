/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/core/invariant"
use "wallaroo/core/sink"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


trait BarrierHandler
  fun name(): String
  fun in_progress(): Bool
  fun ref ack_barrier(s: BarrierReceiver) =>
    _invalid_call()
    Fail()

  fun ref worker_ack_barrier_start(w: String)
  =>
    _invalid_call()
    Fail()

  fun ref worker_ack_barrier(w: String)
  =>
    _invalid_call()
    Fail()

  fun ref check_for_completion() =>
    _invalid_call()
    Fail()

  fun ref _invalid_call() =>
    @printf[I32]("Invalid call on BarrierHandler %s\n".cstring(),
      name().cstring())

class WaitingBarrierHandler is BarrierHandler
  fun name(): String =>
    "WaitingBarrierHandler"
  fun in_progress(): Bool =>
    false

class PendingBarrierHandler is BarrierHandler
  let _worker_name: String
  let _initiator: BarrierInitiator ref
  let _barrier_token: BarrierToken
  let _sinks: SetIs[BarrierReceiver] = _sinks.create()
  let _acked_sinks: SetIs[BarrierReceiver] = _acked_sinks.create()
  let _result_promise: BarrierResultPromise
  let _workers: SetIs[String] = _workers.create()
  let _workers_acked_start: SetIs[String] = _workers_acked_start.create()
  let _workers_acked_barrier: SetIs[String] = _workers_acked_barrier.create()
  // Did we start this barrier?
  let _primary_worker: String

  new create(worker_name: String, i: BarrierInitiator ref,
    barrier_token: BarrierToken, sinks: SetIs[BarrierReceiver] box,
    ws: _StringSet box, result_promise: BarrierResultPromise,
    primary_worker: String)
  =>
    _worker_name = worker_name
    _initiator = i
    _barrier_token = barrier_token
    for s in sinks.values() do
      _sinks.set(s)
    end
    for w in ws.values() do
      _workers.set(w)
    end
    _result_promise = result_promise
    _primary_worker = primary_worker

  fun name(): String =>
    "PendingBarrierHandler"

  fun in_progress(): Bool =>
    true

  fun _is_primary(): Bool =>
    _worker_name == _primary_worker

  fun ref ack_barrier(s: BarrierReceiver) =>
    """
    If we receive barrier acks in this phase, we hold on to them for later.
    """
    // @printf[I32]("!@ ack sink barrier at PendingBarrierHandler\n".cstring())
    if not _sinks.contains(s) then Fail() end

    _acked_sinks.set(s)

  fun ref worker_ack_barrier_start(w: String) =>
    @printf[I32]("worker_ack_barrier_start from PendingBarrierHandler\n".cstring())
    ifdef debug then
      Invariant(if _is_primary() then
        SetHelpers[String].contains[String](_workers, w) else true end)
      Invariant(not SetHelpers[String].contains[String](_workers_acked_start,
        w))
    end
    if _is_primary() then
      // We are the primary, so we need to wait for everyone's ack
      _workers_acked_start.set(w)
      check_for_completion()
    else
      // We're not the primary, so we should only receive an ack from the
      // primary.
      if w == _primary_worker then
        _start_barrier()
      else
        Fail()
      end
    end

  fun ref worker_ack_barrier(w: String) =>
    """
    If we receive worker barrier acks in this phase, we hold on to them for
    later.
    """
    @printf[I32]("worker_ack_barrier from PendingBarrierHandler\n".cstring())
    ifdef debug then
      Invariant(SetHelpers[String].contains[String](_workers, w))
      Invariant(not SetHelpers[String].contains[String](_workers_acked_barrier,
        w))
    end
    _workers_acked_barrier.set(w)

  fun ref check_for_completion() =>
    // @printf[I32]("!@ PendingBarrierHandler _check_for_completion with %s _acked_workers and %s _workers\n".cstring(), _workers_acked_start.size().string().cstring(), _workers.size().string().cstring())
    if _workers_acked_start.size() == _workers.size() then
      _initiator.confirm_start_barrier(_barrier_token)
      _start_barrier()
    end

  fun ref _start_barrier() =>
    let acked_sinks = recover iso SetIs[BarrierReceiver] end
    for s in _acked_sinks.values() do
      acked_sinks.set(s)
    end
    let acked_ws = recover iso SetIs[String] end
    for w in _workers_acked_barrier.values() do
      acked_ws.set(w)
    end
    _initiator.start_barrier(_barrier_token, _result_promise,
      consume acked_sinks, consume acked_ws, _primary_worker)

class InProgressPrimaryBarrierHandler is BarrierHandler
  let _worker_name: String
  let _initiator: BarrierInitiator ref
  let _barrier_token: BarrierToken
  let _sinks: SetIs[BarrierReceiver] = _sinks.create()
  let _acked_sinks: SetIs[BarrierReceiver] = _acked_sinks.create()
  let _result_promise: BarrierResultPromise
  let _workers: SetIs[String] = _workers.create()
  let _workers_acked: SetIs[String] = _workers_acked.create()

  new create(worker_name: String, i: BarrierInitiator ref,
    barrier_token: BarrierToken, acked_sinks: SetIs[BarrierReceiver] box,
    acked_ws: SetIs[String] box, sinks: SetIs[BarrierReceiver] box,
    ws: _StringSet box, result_promise: BarrierResultPromise)
  =>
    _worker_name = worker_name
    _initiator = i
    _barrier_token = barrier_token
    for s in acked_sinks.values() do
      _acked_sinks.set(s)
    end
    for w in acked_ws.values() do
      _workers_acked.set(w)
    end
    for s in sinks.values() do
      _sinks.set(s)
    end
    for w in ws.values() do
      _workers.set(w)
    end
    _result_promise = result_promise

  fun name(): String =>
    "InProgressPrimaryBarrierHandler"

  fun in_progress(): Bool =>
    true

  fun ref ack_barrier(s: BarrierReceiver) =>
    // @printf[I32]("!@ ack_barrier at InProgressPrimaryBarrierHandler\n".cstring())
    if not _sinks.contains(s) then Fail() end

    _acked_sinks.set(s)
    check_for_completion()

  fun ref worker_ack_barrier(w: String) =>
    """
    If we receive worker acks in this phase, we hold on to them for later.
    """
    @printf[I32]("worker_ack_barrier from InProgressPrimaryBarrierHandler\n".cstring())
    ifdef debug then
      Invariant(SetHelpers[String].contains[String](_workers, w))
      Invariant(not SetHelpers[String].contains[String](_workers_acked, w))
    end
    _workers_acked.set(w)

  fun ref check_for_completion() =>
    // @printf[I32]("!@ InProgressPrimaryBarrierHandler _check_for_completion with %s _acked_sinks and %s _sinks\n".cstring(), _acked_sinks.size().string().cstring(), _sinks.size().string().cstring())
    if _acked_sinks.size() == _sinks.size() then
      let acked_ws = recover iso SetIs[String] end
      for w in _workers_acked.values() do
        acked_ws.set(w)
      end
      _initiator.all_primary_sinks_acked(_barrier_token, consume acked_ws,
        _result_promise)
    end

class InProgressSecondaryBarrierHandler is BarrierHandler
  let _initiator: BarrierInitiator ref
  let _barrier_token: BarrierToken
  let _sinks: SetIs[BarrierReceiver] = _sinks.create()
  let _acked_sinks: SetIs[BarrierReceiver] = _acked_sinks.create()
  let _primary_worker: String

  new create(i: BarrierInitiator ref, barrier_token: BarrierToken,
    acked_sinks: SetIs[BarrierReceiver] box, sinks: SetIs[BarrierReceiver] box,
    primary_worker: String)
  =>
    _initiator = i
    _barrier_token = barrier_token
    for s in acked_sinks.values() do
      _acked_sinks.set(s)
    end
    for s in sinks.values() do
      _sinks.set(s)
    end
    _primary_worker = primary_worker

  fun name(): String =>
    "InProgressSecondaryBarrierHandler"

  fun in_progress(): Bool =>
    true

  fun ref ack_barrier(s: BarrierReceiver) =>
    if not _sinks.contains(s) then Fail() end

    _acked_sinks.set(s)
    check_for_completion()

  fun ref check_for_completion() =>
    if _acked_sinks.size() == _sinks.size() then
      _initiator.all_secondary_sinks_acked(_barrier_token, _primary_worker)
    end

class WorkerAcksBarrierHandler is BarrierHandler
  let _initiator: BarrierInitiator ref
  let _barrier_token: BarrierToken
  let _workers: SetIs[String] = _workers.create()
  let _acked_workers: SetIs[String] = _acked_workers.create()
  let _result_promise: BarrierResultPromise

  new create(i: BarrierInitiator ref, ifa_id: BarrierToken,
    ws: _StringSet box, ws_acked: SetIs[String] val,
    result_promise: BarrierResultPromise)
  =>
    _initiator = i
    _barrier_token = ifa_id
    for w in ws.values() do
      _workers.set(w)
    end
    for w in ws_acked.values() do
      ifdef debug then
        Invariant(SetHelpers[String].contains[String](_workers, w))
      end
      _acked_workers.set(w)
    end
    _result_promise = result_promise

  fun name(): String =>
    "WorkerAcksBarrierHandler"

  fun in_progress(): Bool =>
    true

  fun ref worker_ack_barrier(w: String) =>
    @printf[I32]("!@ worker_ack_barrier for %s from WorkerAcksBarrierHandler\n".cstring(), w.cstring())
    if not SetHelpers[String].contains[String](_workers, w) then Fail() end

    _acked_workers.set(w)
    check_for_completion()

  fun ref check_for_completion() =>
    if _acked_workers.size() == _workers.size() then
      // @printf[I32]("!@ All workers are completed for acks!\n".cstring())
      _initiator.all_workers_acked(_barrier_token, _result_promise)
    else
      None
      // @printf[I32]("!@ Only %s of %s workers have acked!\n".cstring(), _acked_workers.size().string().cstring(), _workers.size().string().cstring())
    end
