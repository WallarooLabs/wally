/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "buffered"
use "collections"
use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestFallorMsgEncoder)
    test(_TestFallorTimestampRaw)
    test(_TestGeneralExtEncDecSimple)
    test(_TestGeneralExtEncDecShrink)

class iso _TestFallorMsgEncoder is UnitTest
  fun name(): String => "messages/_TestFallorMsgEncoder"

  fun apply(h: TestHelper) ? =>
    let test: Array[String] val = recover val ["hi"; "there"; "pal"; "!"] end

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
    let msgs = FallorMsgDecoder(consume bytes)?

    h.assert_eq[USize](msgs.size(), 4)
    h.assert_eq[String](msgs(0)?, "hi")
    h.assert_eq[String](msgs(1)?, "there")
    h.assert_eq[String](msgs(2)?, "pal")
    h.assert_eq[String](msgs(3)?, "!")

class iso _TestFallorTimestampRaw is UnitTest
  fun name(): String => "messages/_TestFallorTimestampRaw"

  fun apply(h: TestHelper) ? =>
    let text: String val = "Hello world"
    let at: U64 = 1234567890
    let msg: Array[U8] val = recover val
      let a': Array[U8] = Array[U8]
      a'.append(text)
      a'
    end
    let byteseqs = FallorMsgEncoder.timestamp_raw(at, consume msg)
    // Decoder expects a single stream of bytes, so we need to join
    // the byteseqs into a single Array[U8]
    let encoded: Array[U8] iso = recover Array[U8] end
    for seq in byteseqs.values() do
      encoded.append(seq)
    end
    let tup = FallorMsgDecoder.with_timestamp(consume encoded)?
    h.assert_eq[USize](tup.size(), 2)
    h.assert_eq[String](tup(0)?, at.string())
    h.assert_eq[String](tup(1)?, text)

interface _EncoderFn0
  fun ref apply(wb: Writer): Array[ByteSeq] val

interface _EncoderFn1
  fun ref apply(str: String, wb: Writer): Array[ByteSeq] val

interface _ExtractFn
  fun val apply(em: ExternalMsg): (String | None)

primitive Help
  fun val flatten(e1: Array[ByteSeq] val): Array[U8] val =>
    // Decoder expects a single stream of bytes, so we need to join
    // the byteseqs into a single Array[U8]
    let e1': Array[U8] trn = recover Array[U8] end
    for seq in e1.values() do
      e1'.append(seq)
    end
  consume e1'

  fun general(h: TestHelper, enc: (_EncoderFn0 | _EncoderFn1),
    extr: _ExtractFn val) ?
  =>
    let str1: String val = "a string"
    let wb1: Writer ref = Writer

    let e1: Array[ByteSeq] val =
      match enc
      | let e: _EncoderFn0 =>
        e(wb1)
      | let e: _EncoderFn1 =>
        e(str1, wb1)
      end

    // encode & decode are not symmetric -- we need to chop off
    // the first 4 bytes before we can decode.
    let e1': Array[U8] val = recover Help.flatten(e1).slice(4) end
    let extracted: (String | None) =
      (extr)(ExternalMsgDecoder(e1')?)
    match extracted
    | None =>
      // Lambda extractor already matched correct type, nothing more to do"
      None
    | let ex: String =>
      h.assert_eq[String](str1, ex)
    end

class iso _TestGeneralExtEncDecSimple is UnitTest
  fun name(): String => "General Encode/decode for simple external messages"

  fun apply(h: TestHelper) ? =>
    Help.general(h, ExternalMsgEncoder~data(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalDataMsg => x.data
        else "bad data" end
      })?
    Help.general(h, ExternalMsgEncoder~ready(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalReadyMsg => x.node_name
        else "bad read" end
      })?
    Help.general(h, ExternalMsgEncoder~topology_ready(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalTopologyReadyMsg => x.node_name
        else "bad topology_ready" end
      })?
    Help.general(h, ExternalMsgEncoder~start(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalStartMsg => None
        else "bad start" end
      })?
    Help.general(h, ExternalMsgEncoder~shutdown(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalShutdownMsg => x.node_name
        else "bad shutdown" end
      })?
    Help.general(h, ExternalMsgEncoder~done(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalDoneMsg => x.node_name
        else "bad done" end
      })?
    Help.general(h, ExternalMsgEncoder~start_giles_senders(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalStartGilesSendersMsg => None
        else "bad start_giles_senders" end
      })?
    Help.general(h, ExternalMsgEncoder~senders_started(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalGilesSendersStartedMsg => None
        else "bad senders_started" end
      })?
    Help.general(h, ExternalMsgEncoder~print_message(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalPrintMsg => x.message
        else "bad print_message" end
      })?
    Help.general(h, ExternalMsgEncoder~rotate_log(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalRotateLogFilesMsg => x.node_name
        else "bad rotate_log" end
      })?
    Help.general(h, ExternalMsgEncoder~clean_shutdown(),
      {(em: ExternalMsg) =>
        match em | let x: ExternalCleanShutdownMsg => x.msg
        else "bad clean_shutdown" end
      })?

class iso _TestGeneralExtEncDecShrink is UnitTest
  fun name(): String => "General Encode/decode for Shrink external messages"

  fun apply(h: TestHelper) ? =>
    """
    Test round-trip serialization of ExternalShrinkMsg.
    """
    let node_names: Array[String] = [""; "a"; "lovely b"; ""; "node c"]

    // Use Range so that num_nodes array size 0 is tested.
    for i in Range[U64](0, node_names.size().u64()) do
      let e1: Array[ByteSeq] val =
        ExternalMsgEncoder.shrink_request(false, node_names.slice(0,
          i.usize()), 0)
      // encode & decode are not symmetric -- we need to chop off
      // the first 4 bytes before we can decode.
      let e1': Array[U8] val = recover Help.flatten(e1).slice(4) end

      match ExternalMsgDecoder(e1')?
      | let extracted: ExternalShrinkRequestMsg =>
        h.assert_eq[Bool](false, extracted.query)
        h.assert_eq[USize](i.usize(), extracted.node_names.size())
        for j in extracted.node_names.keys() do
          h.assert_eq[String](node_names(j)?, extracted.node_names(j)?)
        end
        h.assert_eq[U64](0, extracted.num_nodes)
      else
        h.assert_eq[String]("error", "case 1")
      end
    end

    // Use Range so that num_nodes = 0 is included
    for i in Range[U64](0, 4) do
      let e1: Array[ByteSeq] val = ExternalMsgEncoder.shrink_request(false, [],
        i)
      let e1': Array[U8] val = recover Help.flatten(e1).slice(4) end

      match ExternalMsgDecoder(e1')?
      | let extracted: ExternalShrinkRequestMsg =>
        h.assert_eq[Bool](false, extracted.query)
        h.assert_eq[USize](0, extracted.node_names.size())
        h.assert_eq[U64](i, extracted.num_nodes)
      else
        h.assert_eq[String]("error", "case 2")
      end
    end

    // Let's now try a round trip for a query
    let e2: Array[ByteSeq] val = ExternalMsgEncoder.shrink_request(true, [], 0)
    let e2': Array[U8] val = recover Help.flatten(e2).slice(4) end

    match ExternalMsgDecoder(e2')?
    | let extracted: ExternalShrinkRequestMsg =>
      h.assert_eq[Bool](true, extracted.query)
      h.assert_eq[USize](0, extracted.node_names.size())
      h.assert_eq[U64](0, extracted.num_nodes)
    else
      h.assert_eq[String]("error", "case query")
    end
