/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use ".."
use "collections"

actor Main
  new create(env: Env) =>
    VerifierCLI[WordLengthCountSentMessage val, WordLengthCountReceivedMessage val].run(env, "Word Length Count: External Java Process", WordLengthCountResultMapper, WordLengthCountSentParser, WordLengthReceivedReceivedParser)

class WordLengthCountSentMessage
  let ts: U64
  let text: String

  new val create(ts': U64, text': String) =>
    ts = ts'
    text = text'

  fun string(): String iso^ =>
    ("(" + ts.string() + ", " + text + ")").clone()

class WordLengthCountReceivedMessage
  let ts: U64
  let text: String
  let len: U64

  new val create(ts': U64, text': String, len': U64) =>
    ts = ts'
    text = text'
    len = len'

  fun string(): String iso^ =>
    ("(" + ts.string() + ", " + text + ", " + len.string() + ")").clone()

class WordLengthCountSentParser is SentParser[WordLengthCountSentMessage val]
  let _messages: Array[WordLengthCountSentMessage val] = Array[WordLengthCountSentMessage val]

  fun ref apply(fields: Array[String] val) ? =>
    let ts: U64 val = fields(0).clone().strip().u64()
    let text: String val = recover val fields(1).clone().strip() end
    _messages.push(WordLengthCountSentMessage(ts, text))

  fun ref sent_messages(): Array[WordLengthCountSentMessage val] =>
    _messages


class WordLengthReceivedReceivedParser is ReceivedParser[WordLengthCountReceivedMessage val]
  let _messages: Array[WordLengthCountReceivedMessage val] = Array[WordLengthCountReceivedMessage val]

  fun ref apply(fields: Array[String] val) ? =>
    let ts: U64 val = fields(0).clone().strip().u64()
    let values = fields(1).split(":")
    if (values.size() != 2) then
      error
    end
    let text: String val = recover val values(0).clone().strip() end
    let len: U64 val = values(1).clone().strip().u64()
    _messages.push(WordLengthCountReceivedMessage(ts, text, len))

  fun ref received_messages(): Array[WordLengthCountReceivedMessage val] =>
    _messages

class WordLengthCountResultMapper is ResultMapper[WordLengthCountSentMessage val,
  WordLengthCountReceivedMessage val]

  fun sent_transform(sent: Array[WordLengthCountSentMessage val]):
    CanonicalForm =>
    var rs = ResultStore

    for m in sent.values() do
      rs(m.text) = m.text.size().u64()
    end
    rs

  fun received_transform(received: Array[WordLengthCountReceivedMessage val]):
    CanonicalForm =>
    var rs = ResultStore

    for m in received.values() do
      rs(m.text) = m.len
    end
    rs

class ResultStore is CanonicalForm
  let lengths: Map[String, U64] = Map[String, U64]

  fun apply(key: String): U64 ? =>
    lengths(key)

  fun ref update(key: String, value: U64) =>
    let k: String val = recover val key.clone().strip() end
    if k == "" then return end
    lengths(k) = value

  fun compare(that: CanonicalForm): (MatchStatus val, String) =>
    match that
    | let rs: ResultStore =>
      if lengths.size() != rs.lengths.size() then
        return (ResultsDoNotMatch, "Count map sizes do not match up")
      end

      for (key, len) in lengths.pairs() do
        try
          if len != rs(key) then
            let msg: String = "Expected " + key + " to have a length of " + len.string() + " instead of " + rs(key).string()
            return (ResultsDoNotMatch, msg)
          end
        else
          let msg = "Couldn't find " + key + " in results"
          return (ResultsDoNotMatch, msg)
        end
      end

      (ResultsMatch, "")
    else
      (ResultsDoNotMatch, "")
    end
