use "collections"

use "lib:wallaroo"

use @free[None](p: Pointer[U8] box)
use @ApplicationSetup[Pointer[U8] val](show_help: Bool)

use @RemoveComponent[None](cid: U64, ctype: U64)

use @ComponentSerializeGetSpaceWrapper[U64](cid: U64, ctype: U64)
use @ComponentSerializeWrapper[None](cid: U64, p: Pointer[U8] tag, ctype: U64)
use @ComponentDeserializeWrapper[U64](p: Pointer[U8] tag, ctype: U64)

primitive ApplicationSetup
  fun apply(show_help: Bool): String =>
    recover val
      let cs = @ApplicationSetup(show_help)
      let s' = String.copy_cstring(cs)
      @free(cs)
      s'
    end

primitive ComponentSerializeGetSpace
  fun apply(cid: U64, ctype: U64): USize =>
    @ComponentSerializeGetSpaceWrapper(cid, ctype).usize()

primitive ComponentSerialize
  fun apply(cid: U64, p: Pointer[U8] tag, ctype: U64)  =>
    @ComponentSerializeWrapper(cid, p, ctype)

primitive ComponentDeserialize
  fun apply(p: Pointer[U8] tag, ctype: U64): U64 =>
    @ComponentDeserializeWrapper(p, ctype)

primitive RemoveComponent
  fun apply(cid: U64, ctype: U64) =>
    @RemoveComponent(cid, ctype)

primitive ComponentType
  fun data(): U64 => 0
  fun computation(): U64 => 1
  fun computation_builder(): U64 => 2
  fun state_computation(): U64 => 3
  fun partition_function(): U64 => 4
  fun partition_list(): U64 => 5
  fun encoder(): U64 => 6
  fun decoder(): U64 => 7
  fun state(): U64 => 8
  fun state_builder(): U64 => 9
