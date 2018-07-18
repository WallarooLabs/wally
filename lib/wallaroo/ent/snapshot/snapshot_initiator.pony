/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "promises"
use "time"
use "wallaroo/core/common"
use "wallaroo/core/initialization"
use "wallaroo/core/sink"
use "wallaroo/core/source"
use "wallaroo/core/topology"
use "wallaroo/ent/barrier"
use "wallaroo/ent/network"
use "wallaroo_labs/mort"


actor SnapshotInitiator is Initializable
  var _is_active: Bool
  var _is_primary: Bool
  var _time_between_snapshots: U64
  let _barrier_initiator: BarrierInitiator
  //!@
  // var _snapshot_handler: SnapshotHandler = WaitingSnapshotHandler(this)
  var _current_snapshot_id: SnapshotId = 0
  let _connections: Connections
  let _source_ids: Map[USize, StepId] = _source_ids.create()
  let _timers: Timers = Timers

  new create(connections: Connections, time_between_snapshots: U64,
    barrier_initiator: BarrierInitiator, is_active: Bool = true,
    is_primary: Bool = false)
  =>
    _is_active = is_active
    _is_primary = is_primary
    _time_between_snapshots = time_between_snapshots
    _barrier_initiator = barrier_initiator
    _connections = connections

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    ifdef "resilience" then
      if _is_active and _is_primary then
        let t = Timer(_InitiateSnapshot(this), _time_between_snapshots)
        _timers(consume t)
      end
    end

  be initiate_snapshot() =>
    _current_snapshot_id = _current_snapshot_id + 1
    let token = SnapshotBarrierToken(_current_snapshot_id)
    let action = Promise[BarrierToken]
    action.next[None](recover this~snapshot_complete() end)
    _barrier_initiator.initiate_barrier(token, action)

  be snapshot_complete(token: BarrierToken) =>
    ifdef "resilience" then
      match token
      | let st: SnapshotBarrierToken =>
        if st.id != _current_snapshot_id then Fail() end
        @printf[I32]("!@ SnapshotInitiator: Snapshot is complete!\n".cstring())
        //!@ Write snapshot id to disk

        //!@ Inform other workers to write snapshot id to disk
        // Prepare for next snapshot
        if _is_active and _is_primary then
          //!@ In reality, we'll need to check if this is allowed
          let t = Timer(_InitiateSnapshot(this), _time_between_snapshots)
          _timers(consume t)
        end
      else
        Fail()
      end
    else
      Fail()
    end

class _InitiateSnapshot is TimerNotify
  let _si: SnapshotInitiator

  new iso create(si: SnapshotInitiator) =>
    _si = si

  fun ref apply(timer: Timer, count: U64): Bool =>
    _si.initiate_snapshot()
    false
