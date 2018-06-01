use "collections"
use "itertools"
use "wallaroo/core/boundary"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"
use "wallaroo/ent/recovery"
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

  var _next_step_id: StepId = 0

  let _app_name: String
  let _worker_name: String
  let _metrics_conn: MetricsSink
  let _auth: AmbientAuth
  let _event_log: EventLog
  var _recovery_replayer: (None | RecoveryReplayer) = None
  // !@ This will need to be updated when new boundaries are introduced
  var _outgoing_boundaries: (None | Map[String, OutgoingBoundary] val) = None

  let _runner_builders: Map[String, RunnerBuilder] = _runner_builders.create()

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
    omni_router: OmniRouter) =>
    None

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be report_unknown_key(producer: Producer, state_name: String, key: Key) =>
    try
      producer.update_keyed_route(state_name, key,
        _keys_to_steps(state_name, key)?, _keys_to_step_ids(state_name, key)?)
    else
      @printf[I32]("State Step Creator should create step for key '%s'\n"
        .cstring(), key.cstring())

      try
        (let recovery_replayer, let outgoing_boundaries) = try
          (_recovery_replayer as RecoveryReplayer,
            _outgoing_boundaries as Map[String, OutgoingBoundary] val)
        else
          @printf[I32]("Could not find runner_builder for state '%s'\n".cstring(),
            state_name.cstring())
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

        let id = _next_step_id = _next_step_id + 1
        let state_step = Step(_auth, runner_builder(
          where event_log = _event_log, auth = _auth),
          consume reporter, id, runner_builder.route_builder(),
          _event_log, recovery_replayer, outgoing_boundaries,
          this)

        _keys_to_steps.add(state_name, key, state_step)
        _keys_to_step_ids.add(state_name, key, id)

        producer.update_keyed_route(state_name, key,
          state_step, id)
      end
    end

  be add_builder(state_name: String, runner_builder: RunnerBuilder) =>
    _runner_builders(state_name) = runner_builder

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

    _next_step_id = _find_highest_step_id() + 1

    initializer.report_initialized(this)

  fun ref _find_highest_step_id(): StepId =>
    var highest: StepId = 0

    for (_, _, id) in _keys_to_step_ids.pairs() do
      if id > highest then
        highest = id
      end
    end
    highest
