use "sendence/connemara"
use "promises"

actor Main is TestList
  new create(env: Env) => Connemara(env, this)

  new make() => None

  fun tag tests(test: Connemara) =>
    test(_TestBytes)

class iso _TestBytes is UnitTest
  fun name(): String => "bytes/_TestBytes"

  fun apply(h: TestHelper) ? =>
    let n1: U16 = 43156
    let n1_enc: Array[U8] val = Bytes.from_u16(n1)
    let n1_dec: U16 =
      Bytes.to_u16(n1_enc(0), n1_enc(1))
    h.assert_eq[U16](n1_dec, n1)

    let n2: U32 = 2843253
    let n2_enc: Array[U8] val = Bytes.from_u32(n2)
    let n2_dec: U32 =
      Bytes.to_u32(n2_enc(0), n2_enc(1), n2_enc(2), n2_enc(3))
    h.assert_eq[U32](n2_dec, n2)

    let n3: U64 = 238412413
    let n3_enc: Array[U8] val = Bytes.from_u64(n3)
    let n3_dec: U64 = Bytes.to_u64(n3_enc(0), n3_enc(1), n3_enc(2), n3_enc(3),
      n3_enc(4), n3_enc(5), n3_enc(6), n3_enc(7))
    h.assert_eq[U64](n3_dec, n3)

    true
