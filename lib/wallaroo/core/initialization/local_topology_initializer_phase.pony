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

use "collections"
use "net"

use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/checkpoint"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/mort"


trait LocalTopologyInitializerPhase
  fun name(): String

  fun ref set_initializable(initializable: Initializable) =>
    """
    If this is called after initialization is begun, then we ignore that
    initializable for now. This will happen as boundaries are added.
    """
    None

  fun ref initialize(lti: LocalTopologyInitializer ref,
    cluster_initializer: (ClusterInitializer | None),
    checkpoint_target: (CheckpointId | None),
    recovering_without_resilience: Bool, worker_count: (USize | None))
  =>
    // Currently, recovery in a single worker cluster is a special case.
    // We do not need to recover connections to other workers, so we
    // initialize immediately in Startup. However, we eventually trigger
    // code in connections.pony where initialize() is called again. For
    // now, this code simply does nothing in that scenario to avoid double
    // initialization.
    match worker_count
    | let wc: USize =>
        if wc == 1 then
          @printf[I32](("LocalTopologyInitializer.initialize called a " +
            "second time. Ignoring since this is a single worker cluster.\n")
            .cstring())
        else
          // If this is not a recovering single worker cluster, then
          // initialize has been called during the wrong phase.
          _invalid_call()
          Fail()
        end
    else
      // If worker_count is None, then we have not yet initialized the
      // LocalTopology, which means this has been called during the wrong
      // phase.
      _invalid_call()
      Fail()
    end

  fun ref begin_reporting() =>
    _invalid_call(); Fail()

  fun ref report_created(initializable: Initializable) =>
    _invalid_call(); Fail()

  fun ref report_initialized(initializable: Initializable) =>
    _invalid_call(); Fail()

  fun ref report_ready_to_work(initializable: Initializable) =>
    _invalid_call(); Fail()

  fun ref worker_report_ready_to_work(w: WorkerName) =>
    _invalid_call(); Fail()

  fun ref all_workers_ready_to_work() =>
    _invalid_call(); Fail()

  fun ref report_event_log_ready_to_work() =>
    // !TODO!: For now, this is partially handled by the
    // LocalTopologyInitializer, so we do nothing if this occurs outside
    // an expected phase.
    None

  fun ref report_recovery_ready_to_work() =>
    // !TODO!: For now, this is partially handled by the
    // LocalTopologyInitializer, so we do nothing if this occurs outside
    // an expected phase.
    None

  fun ref cluster_status_query(lti: LocalTopologyInitializer ref,
    conn: TCPConnection)
  =>
    lti._cluster_status_query_not_initialized(conn)

  fun _invalid_call() =>
    @printf[I32]("Invalid call on local topology initializer phase %s\n"
      .cstring(), name().cstring())

class _ApplicationAwaitingInitializationPhase is LocalTopologyInitializerPhase
  let _initializables: Initializables = Initializables
  let _workers_ready_to_work: SetIs[WorkerName] =
    _workers_ready_to_work.create()

  fun name(): String => "_ApplicationAwaitingInitializationPhase"

  fun ref set_initializable(initializable: Initializable) =>
    _initializables.set(initializable)

  fun ref initialize(lti: LocalTopologyInitializer ref,
    cluster_initializer: (ClusterInitializer | None),
    checkpoint_target: (CheckpointId | None),
    recovering_without_resilience: Bool, worker_count: (USize | None))
  =>
    lti._initialize(_initializables, cluster_initializer, checkpoint_target,
      recovering_without_resilience, _workers_ready_to_work)

  fun ref worker_report_ready_to_work(w: WorkerName) =>
    _workers_ready_to_work.set(w)

class _ApplicationBeginReportingPhase is LocalTopologyInitializerPhase
  let _lti: LocalTopologyInitializer ref
  let _initializables: Initializables
  let _created: SetIs[Initializable] = _created.create()
  let _workers_ready_to_work: SetIs[WorkerName]

  new create(lti: LocalTopologyInitializer ref, i: Initializables,
    workers_ready_to_work: SetIs[WorkerName])
  =>
    _lti = lti
    _initializables = i
    _workers_ready_to_work = workers_ready_to_work

  fun name(): String => "_ApplicationBeginReportingPhase"

  fun ref begin_reporting() =>
    if _initializables.size() == 0 then
      @printf[I32](("Phases I-II skipped (this topology must only have " +
        "sources.)\n").cstring())
      _lti.application_ready_to_work(_initializables,
        _workers_ready_to_work)
    else
      _initializables.application_begin_reporting(_lti)
    end

  fun ref report_created(initializable: Initializable) =>
    if not _created.contains(initializable) then
      _created.set(initializable)
      if _created.size() == _initializables.size() then
        _lti._application_created(_initializables,
          _workers_ready_to_work)
      end
    else
      @printf[I32]("The same Initializable reported being created twice\n"
        .cstring())
      Fail()
    end

  fun ref worker_report_ready_to_work(w: WorkerName) =>
    _workers_ready_to_work.set(w)

class _ApplicationCreatedPhase is LocalTopologyInitializerPhase
  let _lti: LocalTopologyInitializer ref
  let _initializables: Initializables
  let _initialized: SetIs[Initializable] = _initialized.create()
  let _workers_ready_to_work: SetIs[WorkerName]

  new create(lti: LocalTopologyInitializer ref,
    initializables: Initializables, workers_ready_to_work: SetIs[WorkerName])
  =>
    @printf[I32]("|~~ INIT PHASE I: Application is created! ~~|\n"
      .cstring())
    _lti = lti
    _initializables = initializables
    _initializables.application_created(_lti)
    _workers_ready_to_work = workers_ready_to_work

  fun name(): String => "_ApplicationCreatedPhase"

  fun ref report_initialized(initializable: Initializable) =>
    if not _initialized.contains(initializable) then
      _initialized.set(initializable)
      if _initialized.size() == _initializables.size() then
        _lti._application_initialized(_initializables,
          _workers_ready_to_work)
      end
    else
      @printf[I32]("The same Initializable reported being initialized twice\n"
        .cstring())
      // !TODO!: Bring this back and solve bug
      // Fail()
    end

  fun ref worker_report_ready_to_work(w: WorkerName) =>
    _workers_ready_to_work.set(w)

class _ApplicationInitializedPhase is LocalTopologyInitializerPhase
  let _lti: LocalTopologyInitializer ref
  let _initializables: Initializables
  let _ready_to_work: SetIs[Initializable] = _ready_to_work.create()
  let _workers_ready_to_work: SetIs[WorkerName]

  new create(lti: LocalTopologyInitializer ref,
    initializables: Initializables, workers_ready_to_work: SetIs[WorkerName])
  =>
    @printf[I32]("|~~ INIT PHASE II: Application is initialized! ~~|\n"
      .cstring())
    _lti = lti
    _initializables = initializables
    _initializables.application_initialized(_lti)
    _workers_ready_to_work = workers_ready_to_work

  fun name(): String => "_ApplicationInitializedPhase"

  fun ref report_ready_to_work(initializable: Initializable) =>
    if not _ready_to_work.contains(initializable) then
      _ready_to_work.set(initializable)
      if _ready_to_work.size() == _initializables.size() then
        _lti._initializables_ready_to_work(_initializables,
          _workers_ready_to_work)
      end
    else
      @printf[I32](("The same Initializable reported being ready to work " +
        "twice\n").cstring())
      Fail()
    end

  fun ref worker_report_ready_to_work(w: WorkerName) =>
    _workers_ready_to_work.set(w)

class _InitializablesReadyToWorkPhase is LocalTopologyInitializerPhase
  let _lti: LocalTopologyInitializer ref
  let _initializables: Initializables
  var _recovery_ready_to_work: Bool
  var _event_log_ready_to_work: Bool
  let _workers_ready_to_work: SetIs[WorkerName]

  new create(lti: LocalTopologyInitializer ref,
    initializables: Initializables, recovery_ready_to_work: Bool,
    event_log_ready_to_work: Bool, workers_ready_to_work: SetIs[WorkerName])
  =>
    _lti = lti
    _initializables = initializables
    _recovery_ready_to_work = recovery_ready_to_work
    _event_log_ready_to_work = event_log_ready_to_work
    _workers_ready_to_work = workers_ready_to_work

  fun name(): String => "_InitializablesReadyToWorkPhase"

  fun ref report_event_log_ready_to_work() =>
    _event_log_ready_to_work = true
    if _recovery_ready_to_work then
      _lti.application_ready_to_work(_initializables,
        _workers_ready_to_work)
    end

  fun ref report_recovery_ready_to_work() =>
    _recovery_ready_to_work = true
    if _event_log_ready_to_work then
      _lti.application_ready_to_work(_initializables,
        _workers_ready_to_work)
    end

  fun ref worker_report_ready_to_work(w: WorkerName) =>
    _workers_ready_to_work.set(w)

class _ApplicationReadyToWorkPhase is LocalTopologyInitializerPhase
  let _lti: LocalTopologyInitializer ref
  let _initializables: Initializables
  let _workers: SetIs[WorkerName] = _workers.create()
  let _workers_ready_to_work: SetIs[WorkerName]
  let _is_initializer: Bool

  new create(lti: LocalTopologyInitializer ref,
    initializables: Initializables, workers: Array[WorkerName] val,
    workers_ready_to_work: SetIs[WorkerName],
    is_initializer: Bool)
  =>
    @printf[I32]("|~~ INIT PHASE III: Application is ready to work! ~~|\n"
      .cstring())
    _lti = lti
    _initializables = initializables
    _initializables.application_ready_to_work(_lti)
    _workers_ready_to_work = workers_ready_to_work
    _is_initializer = is_initializer
    for w in workers.values() do
      _workers.set(w)
    end
    if not _is_initializer then
      _lti.send_worker_ready_to_work_report()
    end

  fun name(): String => "_ApplicationReadyToWorkPhase"

  fun ref report_ready_to_work(initializable: Initializable) =>
    None

  fun ref report_recovery_ready_to_work() =>
    None

  fun ref report_event_log_ready_to_work() =>
    None

  fun ref worker_report_ready_to_work(w: WorkerName) =>
    if _is_initializer then
      _workers_ready_to_work.set(w)
      if _workers_ready_to_work.size() == _workers.size() then
        _lti._cluster_ready_to_work(_initializables)
      end
    end

  fun ref all_workers_ready_to_work() =>
    if not _is_initializer then
      _lti._cluster_ready_to_work(_initializables)
    end

  fun ref cluster_status_query(lti: LocalTopologyInitializer ref,
    conn: TCPConnection)
  =>
    lti._cluster_status_query_initialized(conn)

class _ClusterReadyToWorkPhase is LocalTopologyInitializerPhase
  let _lti: LocalTopologyInitializer ref

  new create(lti: LocalTopologyInitializer ref,
    initializables: Initializables)
  =>
    @printf[I32]("|~~ INIT PHASE IV: Cluster is ready to work! ~~|\n"
      .cstring())
    _lti = lti
    initializables.cluster_ready_to_work(_lti)

  fun name(): String => "_ClusterReadyToWorkPhase"

  fun ref report_ready_to_work(initializable: Initializable) =>
    None

  fun ref report_recovery_ready_to_work() =>
    None

  fun ref report_event_log_ready_to_work() =>
    None

  fun ref worker_report_ready_to_work(w: WorkerName) =>
    None

  fun ref all_workers_ready_to_work() =>
    None

  fun ref cluster_status_query(lti: LocalTopologyInitializer ref,
    conn: TCPConnection)
  =>
    lti._cluster_status_query_initialized(conn)
