use "sendence/connemara"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() => None

  fun tag tests(test: Connemara) =>
    test(_TestFallorMsgEncoder)
    test(_TestFallorTimestampRaw)

class iso _TestFallorMsgEncoder is UnitTest
  fun name(): String => "messages/_TestFallorMsgEncoder"

  fun apply(h: TestHelper) ? =>
    let test: Array[String] val = recover val ["hi", "there", "man", "!"] end

    let byteseqs = FallorMsgEncoder(test)
    let bytes: Array[U8] iso = recover Array[U8] end
    var header_count: USize = 4
    for bs in byteseqs.values() do
      match bs
      | let str: String =>
        bytes.append(str.array())
      | let arr_b: Array[U8] val =>
        for b in arr_b.values() do
          if header_count > 0 then
            header_count = header_count - 1
          else
            bytes.push(b)
          end
        end
      end
    end
    let msgs = FallorMsgDecoder(consume bytes)

    h.assert_eq[USize](msgs.size(), 4)
    h.assert_eq[String](msgs(0), "hi")
    h.assert_eq[String](msgs(1), "there")
    h.assert_eq[String](msgs(2), "man")
    h.assert_eq[String](msgs(3), "!")

class iso _TestFallorTimestampRaw is UnitTest
  fun name(): String => "messages/_TestFallorTimestampRaw"

  fun apply(h: TestHelper) ? =>
    let text: String val = "Hello world"
    let at: U64 = 1234567890
    let msg: Array[U8] val = recover val
      let a': Array[U8] = Array[U8]
      a'.append(text)
    end
    let byteseqs = FallorMsgEncoder.timestamp_raw(at, consume msg)
    // Decoder expects a single stream of bytes, so we need to join
    // the byteseqs into a single Array[U8]
    let encoded: Array[U8] iso = recover Array[U8] end
    for seq in byteseqs.values() do
      encoded.append(seq)
    end
    let tup = FallorMsgDecoder.with_timestamp(consume encoded)
    h.assert_eq[USize](tup.size(), 2)
    h.assert_eq[String](tup(0), at.string())
    h.assert_eq[String](tup(1), text)
