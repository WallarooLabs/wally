use "collections"
use "debug"
use w = "wallaroo/core/topology"

use @ComputationName[Pointer[U8] ref](cid: U64)
use @ComputationCompute[U64](cid: U64, did: U64)
use @ComputationBuilderBuild[U64](cbid: U64)

use @ComputationMultiName[Pointer[U8] ref](cid: U64)
use @ComputationMultiCompute[U64](cid: U64, did: U64, sz: Pointer[U64])
use @ComputationMultiBuilderBuild[U64](cbid: U64)

use @GetMultiResultItem[U64](rid: U64, idx: U64)

class Computation is w.Computation[GoData, GoData]
  var _computation_id: U64

  new create(computation_id: U64) =>
    _computation_id = computation_id

  fun name(): String =>
    recover val
      let sp = @ComputationName(_computation_id)
      let n = String.copy_cstring(sp)
      @free(sp)
      n
    end

  fun apply(data: GoData): (GoData | None) =>
    let res = @ComputationCompute(_computation_id, data.id())

    match res
    | 0 =>
      None
    else
      GoData(res)
    end

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_computation_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_computation_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_computation_id)

class val ComputationBuilder
  var _computation_builder_id: U64

  new val create(computation_builder_id: U64) =>
    _computation_builder_id = computation_builder_id

  fun apply(): Computation iso^ =>
    recover Computation(@ComputationBuilderBuild(_computation_builder_id)) end

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_computation_builder_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_computation_builder_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation_builder_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_computation_builder_id)

class ComputationMulti is w.Computation[GoData, GoData]
  var _computation_id: U64

  new create(computation_id: U64) =>
    _computation_id = computation_id

  fun name(): String =>
    recover val
      let sp = @ComputationMultiName(_computation_id)
      let n = String.copy_cstring(sp)
      @free(sp)
      n
    end

  fun apply(data: GoData): (Array[GoData] val | None) =>
    var size: U64 = 0

    let res = @ComputationMultiCompute(_computation_id, data.id(), addressof size)

    match res
    | 0 =>
      None
    else
      recover
        let results = recover trn Array[GoData](size.usize()) end
        for i in Range(0, size.usize()) do
          results.push(GoData(@GetMultiResultItem(res, i.u64())))
        end
        @RemoveComponent(res)
        consume results
      end
    end

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_computation_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_computation_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_computation_id)

class val ComputationMultiBuilder
  var _computation_builder_id: U64

  new val create(computation_builder_id: U64) =>
    _computation_builder_id = computation_builder_id

  fun apply(): ComputationMulti iso^ =>
    recover ComputationMulti(@ComputationMultiBuilderBuild(_computation_builder_id)) end

  fun _serialise_space(): USize =>
    ComponentSerializeGetSpace(_computation_builder_id)

  fun _serialise(bytes: Pointer[U8] tag) =>
    ComponentSerialize(_computation_builder_id, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation_builder_id = ComponentDeserialize(bytes)

  fun _final() =>
    RemoveComponent(_computation_builder_id)
