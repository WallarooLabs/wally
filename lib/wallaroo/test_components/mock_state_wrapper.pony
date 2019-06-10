use "buffered"
use "ponytest"
use "random"
use "wallaroo/core/common"
use "wallaroo/core/key_registry"
use "wallaroo/core/partitioning"
use "wallaroo/core/state"
use "wallaroo/core/topology"


class ArrayState[InOut: Any val] is State
  let arr: Array[InOut] = arr.create()

class val MockStateInitializer[InOut: Any val] is
  StateInitializer[InOut, InOut, ArrayState[InOut]]
  let _h: TestHelper
  let _auth: AmbientAuth
  let _step_group: RoutingId
  // How many calls to apply before returning retain_state=false
  let _lifetime: (USize | None)

  new val create(h: TestHelper, auth: AmbientAuth, step_group: RoutingId = 1,
    lifetime: (USize | None) = None)
  =>
    _h = h
    _auth = auth
    _step_group = step_group
    _lifetime = lifetime

  fun val state_wrapper(key: Key, rand: Random):
    StateWrapper[InOut, InOut, ArrayState[InOut]]
  =>
    MockStateWrapper[InOut](_h, _lifetime)

  fun name(): String =>
    "MockStateInitializer"

  fun timeout_interval(): U64 =>
    10

  fun val decode(in_reader: Reader, auth: AmbientAuth):
    StateWrapper[InOut, InOut, ArrayState[InOut]]
  =>
    // !TODO! We need a real decoded thing here probably
    MockStateWrapper[InOut](_h, _lifetime)

  fun val runner_builder(step_group_id: RoutingId, parallelization: USize,
    local_routing: Bool): RunnerBuilder
  =>
    StateRunnerBuilder[InOut, InOut, ArrayState[InOut]](this, _step_group,
      10, false)

  fun val create_runner(
    next_runner: Runner iso = RouterRunner(PassthroughPartitionerBuilder),
    key_registry: KeyRegistry = EmptyKeyRegistry): Runner
  =>
    StateRunner[InOut, InOut, ArrayState[InOut]](_step_group, this,
      key_registry, _EventLogDummyBuilder(_auth), _auth,
      _MetricsReporterDummyBuilder(), consume next_runner, false)

class MockStateWrapper[InOut: Any val]
  is StateWrapper[InOut, InOut, ArrayState[InOut]]
  let _h: TestHelper
  var _lifetime: (USize | None)

  new create(h: TestHelper, lifetime: (USize | None)) =>
    _h = h
    _lifetime = lifetime

  // Return (output, output_watermark_ts)
  fun ref apply(input: InOut, event_ts: U64, watermark_ts: U64):
    (ComputationResult[InOut], U64, Bool)
  =>
    let retain_state =
      match _lifetime
      | let l: USize =>
        let new_l =
          if l > 0 then
            l - 1
          else
            l
          end
        _lifetime = new_l
        new_l > 0
      else
        true
      end
    (input, watermark_ts, retain_state)

  fun ref on_timeout(input_watermark_ts: U64, output_watermark_ts: U64):
    (ComputationResult[InOut], U64, Bool)
  =>
    (None, input_watermark_ts, true)

  fun ref flush_windows(input_watermark_ts: U64,
    output_watermark_ts: U64): (ComputationResult[InOut], U64, Bool)
  =>
    (None, input_watermark_ts, true)

  fun ref encode(auth: AmbientAuth): ByteSeq =>
    // !TODO! Do we need something real here?
    recover Array[U8] end
