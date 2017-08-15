use "buffered"
use "collections"
use "serialise"
use "sendence/bytes"
use "sendence/hub"
use "wallaroo/"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/ent/network"
use "wallaroo/recovery"
use "wallaroo/state"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
	let _app_name: String = "Migration Demo"
	let _worker_name: String = "worker"
  var n: U128 = 0
  new create(env: Env) =>
    let runner_builder = _RunnerBuilderGenerator()

		let event_log = EventLog(env)
		MetricsReporter(_app_name, _worker_name, MetricsSink("localhost", "5001"))
    try
      let auth = env.root as AmbientAuth
      let recovery_replayer =
        RecoveryReplayer(auth, "", _RouterRegistryGenerator(env, auth))

      //CREATE TWO STEPS
      let step_a = Step(runner_builder(event_log, env.root as AmbientAuth),
        MetricsReporter(_app_name, _worker_name, MetricsSink("localhost", "5001")),
        1001, runner_builder.route_builder(), event_log, recovery_replayer)
      let step_b = Step(runner_builder(event_log, env.root as AmbientAuth),
        MetricsReporter(_app_name, _worker_name, MetricsSink("localhost", "5001")),
        1001, runner_builder.route_builder(), event_log, recovery_replayer)
      @printf[I32]("steps created\n".cstring())
      for i in Range(0,100000000) do
        n = i.u128()
      end

      //SEND TO STEP A
      let comp = CountComputation
      for i in Range(0,10) do
        let wrapper = StateComputationWrapper[U64, U64, CountState](i.u64(),
              comp, 1001)
        step_a.run[StateProcessor[CountState]]("step a", 0, wrapper, step_a, i.u128(), None, i.u64(), 0, 0, 0, 0)
      end

      //MIGRATE STATE
      step_a.send_state_to_neighbour(step_b)

      //SEND TO STEP B
      for i in Range(0,100000000) do
        n = i.u128()
      end
      for i in Range(0,10) do
        let wrapper = StateComputationWrapper[U64, U64, CountState](i.u64(),
              comp, 1001)
        step_b.run[StateProcessor[CountState]]("step a", 0, wrapper, step_b, i.u128(), None, i.u64(), 0, 0, 0, 0)
      end
    end

primitive _RunnerBuilderGenerator
  fun apply(): RunnerBuilder =>
		let comp = CountComputation
    StateRunnerBuilder[CountState](
			CountStateBuilder,
			"Count",
      comp.state_change_builders())

class CountStateChange is StateChange[CountState]
  let _id: U64
  let _name: String
  var _count: U64 = 0

  fun name(): String => _name
  fun id(): U64 => _id

  new create(id': U64, name': String) =>
    _id = id'
    _name = name'

  fun ref update(count: U64) =>
    _count = count

  fun apply(state: CountState) =>
    state.count = _count


  fun write_log_entry(out_writer: Writer) => None

  fun ref read_log_entry(in_reader: Reader) => None

class CountStateChangeBuilder is StateChangeBuilder[CountState]
  fun apply(id: U64): StateChange[CountState] =>
    CountStateChange(id, "CountStateChange")

class val CountStateBuilder
  fun apply(): CountState => CountState
  fun name(): String => "Count State"

primitive CountComputation is StateComputation[U64, U64, CountState]
  fun name(): String => "Count Messages"

  fun apply(msg: U64,
    sc_repo: StateChangeRepository[CountState],
    state: CountState): (U64 val, StateChange[CountState] ref)
  =>
    let state_change: CountStateChange ref =
      try
        sc_repo.lookup_by_name("CountStateChange") as CountStateChange
      else
        CountStateChange(0, "CountStateChange")
      end

    let new_count = state.count + 1
    state_change.update(new_count)
		@printf[I32]("%d\n".cstring(), new_count)
    (new_count, state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[CountState]] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[CountState]]
      scbs.push(recover val CountStateChangeBuilder end)
    end

class CountState is State
  var count: U64 = 0


primitive _RouterRegistryGenerator
  fun apply(env: Env, auth: AmbientAuth): RouterRegistry =>
    RouterRegistry(auth, "", _ConnectionsGenerator(env, auth), 0)

primitive _ConnectionsGenerator
  fun apply(env: Env, auth: AmbientAuth): Connections =>
    Connections("", "", env, auth, "", "", "", "", "", "", MetricsSink("", ""),
      "", "", false, "", false)
