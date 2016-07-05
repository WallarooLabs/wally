use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make(env: Env) => None

  fun tag tests(test: PonyTest) =>
    test(_TestFallorMsgEncoder)

class iso _TestFallorMsgEncoder is UnitTest
  fun name(): String => "buffy:FallorMsgEncoder"

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
