use "collections"
use "itertools"
use "wallaroo/core/boundary"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo_labs/mort"

class KeyToStepInfo[Info: Any #share]
  let _info: Map[String, Map[Key, Info]]

  new create() =>
    _info = _info.create()

  fun apply(state_name: String, key: box->Key!): this->Info ? =>
    _info(state_name)?(key)?

  fun ref add(state_name: String, key: Key, info: Info^) =>
    try
      _info.insert_if_absent(state_name, Map[Key, Info])?(key) = info
    end

  fun contains(state_name: String, key: Key): Bool =>
    try
      apply(state_name, key)?
      true
    else
      false
    end

  fun clone(): KeyToStepInfo[Info] iso^ =>
    let c = recover iso KeyToStepInfo[Info].create() end

    for (sn, k_i) in _info.pairs() do
      for (key, info) in k_i.pairs() do
        c.add(sn, key, info)
      end
    end

    c

  fun pairs(): Iter[(String, String, Info)] =>
    """
    Return an iterator over tuples where the first two values are the state name
    and the key, and the last value is the info value.
    """
    Iter[(String, Map[String, Info] box)](_info.pairs()).
      flat_map[(String, (String, Info))](
        { (k_m) => Iter[String].repeat_value(k_m._1)
          .zip[(String, Info)](k_m._2.pairs()) }).
      map[(String, String, Info)](
        { (x) => (x._1, x._2._1, x._2._2) })

actor StateStepCreator is Initializable
  var _keys_to_steps: KeyToStepInfo[Step] = _keys_to_steps.create()
  var _keys_to_step_ids: KeyToStepInfo[StepId] = _keys_to_step_ids.create()

  let _step_id_gen: StepIdGenerator = _step_id_gen.create()

  let _app_name: String
  let _worker_name: String
  let _metrics_conn: MetricsSink
  let _auth: AmbientAuth
  let _event_log: EventLog
  var _recovery_replayer: (None | RecoveryReplayer) = None

  var _outgoing_boundaries: Map[String, OutgoingBoundary] val =
    recover _outgoing_boundaries.create() end

  let _runner_builders: Map[String, RunnerBuilder] = _runner_builders.create()

  var _omni_router: (None | OmniRouter) = None

  let _pending_steps: MapIs[Step, (String, Key, StepId)] =
    _pending_steps.create()

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

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter)
  =>
    _omni_router = omni_router

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be report_unknown_key(producer: Producer, state_name: String, key: Key) =>
    if not _keys_to_steps.contains(state_name, key) then
      @printf[I32]("State Step Creator should create step for key '%s'\n"
        .cstring(), key.cstring())

      try
        (let recovery_replayer, let omni_router) = try
          (_recovery_replayer as RecoveryReplayer,
            _omni_router as OmniRouter)
        else
          @printf[I32]("Missing things in StateStepCreator\n".cstring())
          Fail()
          error
        end

        let reporter = MetricsReporter(_app_name, _worker_name, _metrics_conn)

        let runner_builder = try
          _runner_builders(state_name)?
        else
          @printf[I32]("Could not find runner_builder for state '%s'\n".cstring(),
            state_name.cstring())
          Fail()
          error
        end

        let id = _step_id_gen()
        let state_step = Step(_auth, runner_builder(
          where event_log = _event_log, auth = _auth),
          consume reporter, id, runner_builder.route_builder(),
          _event_log, recovery_replayer, _outgoing_boundaries,
          this
          where omni_router = omni_router)

        _pending_steps(state_step) = (state_name, key, id)
        state_step.initializer_initialized(this)
      end
    end

  be add_builder(state_name: String, runner_builder: RunnerBuilder) =>
    _runner_builders(state_name) = runner_builder

  be set_router_registry(router_registry: RouterRegistry) =>
    _router_registry = router_registry

  be initialize_routes(initializer: LocalTopologyInitializer,
    keys_to_steps: KeyToStepInfo[Step] iso,
    keys_to_step_ids: KeyToStepInfo[StepId] iso,
    recovery_replayer: RecoveryReplayer,
    outgoing_boundaries: Map[String, OutgoingBoundary] val)
  =>
    _keys_to_steps = consume keys_to_steps
    _keys_to_step_ids = consume keys_to_step_ids

    _recovery_replayer = recovery_replayer
    _outgoing_boundaries = outgoing_boundaries

    initializer.report_initialized(this)

  be report_ready_to_work(initializable: Initializable) =>
    """
    Handles the `report_ready_to_work` message from a step once it is ready
    to work.
    """

    match initializable
    | let step: Step =>
      try
        ifdef "trace" then
          @printf[I32](("Got a message that a step is ready!\n").cstring())
        end

        let router_registry = try
          _router_registry as RouterRegistry
        else
          @printf[I32]("StateStepCreator must have a RouterRegistry.\n"
            .cstring())
          Fail()
          return
        end

        (let state_name, let key, let id) =
          _pending_steps(step)?

        _keys_to_steps.add(state_name, key, step)
        _keys_to_step_ids.add(state_name, key, id)

        router_registry.register_state_step(step, state_name, key, id)

      else
        @printf[I32](("StateStepCreator received report_ready_to_work from " +
          "an unknown step.\n").cstring())
        Fail()
      end
    else
      @printf[I32](("StateStepCreator received report_ready_to_work from a " +
        "non-step initializable.\n").cstring())
      Fail()
    end

  // OmniRouter updates

  be add_boundaries(boundaries: Map[String, OutgoingBoundary] val) =>
    _add_boundaries(boundaries)

  fun ref _add_boundaries(boundaries: Map[String, OutgoingBoundary] val) =>
    let new_boundaries = recover iso Map[String, OutgoingBoundary] end

    for (worker, boundary) in _outgoing_boundaries.pairs() do
      new_boundaries(worker) = boundary
    end

    for (worker, boundary) in boundaries.pairs() do
      if not new_boundaries.contains(worker) then
        new_boundaries(worker) = boundary
      end
    end

    _outgoing_boundaries = consume new_boundaries

  be update_omni_router(omni_router: OmniRouter) =>
    _omni_router = omni_router
    _add_boundaries(omni_router.boundaries())

  be remove_boundary(worker: String) =>
    let new_boundaries = recover iso Map[String, OutgoingBoundary] end

    for (worker', boundary) in _outgoing_boundaries.pairs() do
      if worker != worker then
        new_boundaries(worker) = boundary
      end
    end

    _outgoing_boundaries = consume new_boundaries
