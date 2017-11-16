use "collections"
use "wallaroo/core/state"
use w = "wallaroo/core/topology"

use @StateComputationMultiName[Pointer[U8] ref](cid: U64)
use @StateComputationMultiCompute[U64](cid: U64, did: U64, sid: U64,
  sc: Pointer[U64], sz: Pointer[U64])

use @StateComputationName[Pointer[U8] ref](cid: U64)
use @StateComputationCompute[U64](cid: U64, did: U64, sid: U64,
  sc: Pointer[U64])

use @StateBuilderName[Pointer[U8] ref](sbid: U64)
use @StateBuilderBuild[U64](sbid: U64)

class val StateComputation is w.StateComputation[GoData, GoData, GoState]
  var _computation_id: U64

  new val create(computation_id: U64) =>
    _computation_id = computation_id

  fun name(): String =>
    recover val
      let sp = @StateComputationName(_computation_id)
      let n = String.from_cstring(sp)
      @free(sp)
      n
    end

  fun apply(data: GoData, sc_repo: StateChangeRepository[GoState],
    state: GoState):
    ((GoData | None), (None | DirectStateChange))
  =>
    var state_changed: U64 = 0
    let res = @StateComputationCompute(_computation_id, data.id(), state.id(),
      addressof state_changed)

    let state_changed_indicator = if state_changed == 0 then
      None
    else
      DirectStateChange
    end

    match res
    | 0 =>
      (None, state_changed_indicator)
    else
      (GoData(res), state_changed_indicator)
    end

  fun state_change_builders(): Array[StateChangeBuilder[GoState]] val =>
    recover val Array[StateChangeBuilder[GoState] val] end

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_computation_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_computation_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_computation_id)

class val StateComputationMulti is w.StateComputation[GoData, GoData, GoState]
  var _computation_id: U64

  new val create(computation_id: U64) =>
    _computation_id = computation_id

  fun name(): String =>
    recover val
      let sp = @StateComputationMultiName(_computation_id)
      let n = String.from_cstring(sp)
      @free(sp)
      n
    end

  fun apply(data: GoData, sc_repo: StateChangeRepository[GoState],
    state: GoState):
    ((Array[GoData] val | None), (None | DirectStateChange))
  =>
    var state_changed: U64 = 0
    var size: U64 = 0

    let res = @StateComputationMultiCompute(_computation_id, data.id(), state.id(),
      addressof state_changed, addressof size)

    let state_changed_indicator = if state_changed == 0 then
      None
    else
      DirectStateChange
    end

    match res
    | 0 =>
      (None, state_changed_indicator)
    else
      recover
        let results = recover trn Array[GoData](size.usize()) end
        for i in Range(0, size.usize()) do
          results.push(GoData(@GetMultiResultItem(res, i.u64())))
        end
        @RemoveComponent(res)
        (consume results, state_changed_indicator)
      end
    end

  fun state_change_builders(): Array[StateChangeBuilder[GoState]] val =>
    recover val Array[StateChangeBuilder[GoState] val] end

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_computation_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_computation_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_computation_id)

class val StateBuilder
  var _state_builder_id: U64

  new val create(state_builder_id: U64) =>
    _state_builder_id = state_builder_id

  fun name(): String =>
    recover val
      let sp = @StateBuilderName(_state_builder_id)
      let n = String.from_cstring(sp)
      @free(sp)
      n
    end

  fun apply(): GoState =>
    GoState(@StateBuilderBuild(_state_builder_id))

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_state_builder_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_state_builder_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _state_builder_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_state_builder_id)
