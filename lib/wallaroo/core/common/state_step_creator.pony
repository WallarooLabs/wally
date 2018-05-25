use "collections"
use "wallaroo/core/initialization"
use "wallaroo/core/topology"

actor StateStepCreator is Initializable
  let _keys_to_steps: Map[Key, Step] = _keys_to_steps.create()
  let _keys_to_step_ids: Map[Key, StepId] = _keys_to_step_ids.create()

  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    initializer.report_created(this)

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter) =>
    // initializer.report_initialized(this)
    None

  be application_initialized(initializer: LocalTopologyInitializer) =>
    initializer.report_ready_to_work(this)

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None

  be report_unknown_key(producer: Producer, key: Key) =>
    try
      producer.update_keyed_route(key, _keys_to_steps(key)?,
        _keys_to_step_ids(key)?)
    else
      // !@ Need to create new step
      @printf[I32]("State Step Creator should create step for key '%s'\n"
        .cstring(), key.cstring())
    end

  be initialize_routes(initializer: LocalTopologyInitializer,
    keys_to_steps: Map[Key, Step] val,
    keys_to_step_ids: Map[Key, StepId] val)
  =>
    _keys_to_steps.concat(keys_to_steps.pairs())
    _keys_to_step_ids.concat(keys_to_step_ids.pairs())
    initializer.report_initialized(this)
