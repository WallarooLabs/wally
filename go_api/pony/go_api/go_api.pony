use "collections"

use "lib:wallaroo"

use @free[None](p: Pointer[U8] box)
use @ApplicationSetup[Pointer[U8] val]()

use @RemoveComponent[None](cid: U64)

use @ComponentSerializeGetSpaceWrapper[U64](cid: U64)
use @ComponentSerializeWrapper[None](cid: U64, p: Pointer[U8] tag)
use @ComponentDeserializeWrapper[U64](p: Pointer[U8] tag)

primitive ApplicationSetup
  fun apply(): String =>
    recover val
      let cs = @ApplicationSetup()
      let s' = String.copy_cstring(cs)
      @free(cs)
      s'
    end

primitive ComponentSerializeGetSpace
  fun apply(cid: U64): USize =>
    @ComponentSerializeGetSpaceWrapper(cid).usize()

primitive ComponentSerialize
  fun apply(cid: U64, p: Pointer[U8] tag)  =>
    @ComponentSerializeWrapper(cid, p)

primitive ComponentDeserialize
  fun apply(p: Pointer[U8] tag): U64 =>
    @ComponentDeserializeWrapper(p)

primitive RemoveComponent
  fun apply(cid: U64) =>
    @RemoveComponent(cid)
