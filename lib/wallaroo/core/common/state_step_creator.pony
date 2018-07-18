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
use "wallaroo/core/boundary"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo_labs/mort"

actor StateStepCreator is Initializable
  var _keys_to_steps: LocalStatePartitions = _keys_to_steps.create()
  var _keys_to_step_ids: LocalStatePartitionIds = _keys_to_step_ids.create()

  let _step_id_gen: RoutingIdGenerator = _step_id_gen.create()

  let _app_name: String
  let _worker_name: String
  let _metrics_conn: MetricsSink
  let _auth: AmbientAuth
  let _event_log: EventLog
  var _recovery_replayer: (None | RecoveryReplayer) = None

  var _outgoing_boundaries: Map[String, OutgoingBoundary] val =
    recover _outgoing_boundaries.create() end

  var _state_runner_builders: Map[StateName, RunnerBuilder] val =
    recover _state_runner_builders.create() end

  var _target_id_routers: Map[String, TargetIdRouter] =
    _target_id_routers.create()

  let _pending_steps: MapIs[Step, (String, Key, RoutingId)] =
    _pending_steps.create()

  let _known_state_key: Map[String, Set[Key]] =
    _known_state_key.create()

  var _router_registry: (None | RouterRegistry) = None

  new create(auth: AmbientAuth,
    app_name: String,
    worker_name: String,
    metrics_conn: MetricsSink,
    event_log: EventLog)
  =>
    _auth = auth
    _app_name = app_name
    _worker_name = worker_name
    _metrics_conn = metrics_conn
    _event_log = event_log

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer) =>
    initializer.report_initialized(this)

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  fun _state_key_is_known(state_name: String, key: Key): Bool =>
    if _known_state_key.contains(state_name) then
      try
        _known_state_key(state_name)?.contains(key)
      else
        Unreachable()
        false
      end
    else
      false
    end

  fun ref _state_key_known(state_name: String, key: Key) =>
    try
      _known_state_key.insert_if_absent(state_name, Set[Key])?.set(key)
    else
      Unreachable()
    end

  be report_unknown_key(producer: Producer, state_name: String, key: Key) =>
    """
    Creates a new step to handle a previously unknown key if a step does not
    already exist for that key. If a step already exists for the key then
    nothing happens. If a new step is created then the appropriate router will
    be updated and the producers will receive the new router. When the
    producer gets a new router it will check the list of unprocessed messages
    to see if any of them can be handled by the new router.
    """
    if not _state_key_is_known(state_name, key) then
      _state_key_known(state_name, key)

      try
        let reporter = MetricsReporter(_app_name, _worker_name, _metrics_conn)

        let runner_builder = try
          _state_runner_builders(state_name)?
        else
          @printf[I32]("Could not find runner_builder for state '%s'\n".cstring(),
            state_name.cstring())
          Fail()
          error
        end

        let id = _step_id_gen()
        let target_id_router = _target_id_routers(state_name)?
        let state_step = try
          Step(_auth, runner_builder(
            where event_log = _event_log, auth = _auth),
            consume reporter, id, _event_log,
            _recovery_replayer as RecoveryReplayer,
            _outgoing_boundaries, this
            where target_id_router = target_id_router)
        else
          @printf[I32]("Missing things in StateStepCreator\n".cstring())
          Fail()
          error
        end

        _pending_steps(state_step) = (state_name, key, id)
        state_step.quick_initialize(this)
      else
        @printf[I32]("Failed to create new step\n".cstring())
        Fail()
      end
    end

  be set_router_registry(router_registry: RouterRegistry) =>
    _router_registry = router_registry

  be initialize_routes_and_builders(initializer: LocalTopologyInitializer,
    keys_to_steps: LocalStatePartitions iso,
    keys_to_step_ids: LocalStatePartitionIds iso,
    recovery_replayer: RecoveryReplayer,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    state_runner_builders: Map[String, RunnerBuilder] val)
  =>
    _keys_to_steps = consume keys_to_steps
    _keys_to_step_ids = consume keys_to_step_ids

    _recovery_replayer = recovery_replayer
    _outgoing_boundaries = outgoing_boundaries

    _state_runner_builders = state_runner_builders

    initializer.report_initialized(this)

  be report_ready_to_work(step: Step) =>
    """
    Handles the `report_ready_to_work` message from a step once it is ready
    to work.
    """

    try
      ifdef "trace" then
        @printf[I32](("Got a message that a step is ready!\n").cstring())
      end

      (_, (let state_name, let key, let id)) =
        _pending_steps.remove(step)?

      _keys_to_steps.add(state_name, key, step)
      _keys_to_step_ids.add(state_name, key, id)

      try
        (_router_registry as RouterRegistry).register_state_step(step,
          state_name, key, id)
      else
        @printf[I32]("StateStepCreator must have a RouterRegistry.\n"
          .cstring())
        Fail()
        return
      end
    else
      @printf[I32](("StateStepCreator received report_ready_to_work from " +
        "an unknown step.\n").cstring())
      Fail()
    end

  // TargetIdRouter updates

  be add_boundaries(boundaries: Map[String, OutgoingBoundary] val) =>
    _update_boundaries(boundaries)

  fun ref _update_boundaries(boundaries: Map[String, OutgoingBoundary] val) =>
    let new_boundaries = recover iso Map[String, OutgoingBoundary] end

    for (worker, boundary) in _outgoing_boundaries.pairs() do
      new_boundaries(worker) = boundary
    end

    for (worker, boundary) in boundaries.pairs() do
      new_boundaries(worker) = boundary
    end

    _outgoing_boundaries = consume new_boundaries

  be update_target_id_router(state_name: String,
    target_id_router: TargetIdRouter)
  =>
    _target_id_routers(state_name) = target_id_router
    _update_boundaries(target_id_router.boundaries())

  be remove_boundary(worker: String) =>
    let new_boundaries = recover iso Map[String, OutgoingBoundary] end

    for (worker', boundary) in _outgoing_boundaries.pairs() do
      if worker != worker' then
        new_boundaries(worker') = boundary
      end
    end

    _outgoing_boundaries = consume new_boundaries
