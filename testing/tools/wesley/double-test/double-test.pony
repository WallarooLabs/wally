/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use ".."

actor Main
  new create(env: Env) =>
    VerifierCLI[DoubleSentMessage val, DoubleReceivedMessage val]
      .run(env, "Double", DoubleResultMapper, DoubleSentParser,
        DoubleReceivedParser)

class DoubleSentMessage
  let ts: U64
  let v: I64

  new val create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun string(): String iso^ =>
    ("(" + ts.string() + ", " + v.string() + ")").clone()

class DoubleReceivedMessage
  let ts: U64
  let v: I64

  new val create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun string(): String iso^ =>
    ("(" + ts.string() + ", " + v.string() + ")").clone()

class DoubleSentParser is SentParser[DoubleSentMessage val]
  let _messages: Array[DoubleSentMessage val] =
    Array[DoubleSentMessage val]

  fun ref apply(fields: Array[String] val): None ? =>
    let timestamp = fields(0).clone().strip().u64()
    let i = fields(1).clone().strip().i64()
    _messages.push(DoubleSentMessage(timestamp, i))

  fun ref sent_messages(): Array[DoubleSentMessage val] =>
    _messages

class DoubleReceivedParser is ReceivedParser[DoubleReceivedMessage val]
  let _messages: Array[DoubleReceivedMessage val] =
    Array[DoubleReceivedMessage val]

  fun ref apply(fields: Array[String] val): None ? =>
    let timestamp = fields(0).clone().strip().u64()
    let i = fields(1).clone().strip().i64()
    _messages.push(DoubleReceivedMessage(timestamp, i))

  fun ref received_messages(): Array[DoubleReceivedMessage val] =>
    _messages

class DoubleResultMapper
  is ResultMapper[DoubleSentMessage val, DoubleReceivedMessage val]

  fun sent_transform(sent: Array[DoubleSentMessage val]): CanonicalForm =>
    var results = ResultsList[I64]

    for m in sent.values() do
      results.add(m.v * 2)
    end
    results

  fun received_transform(received: Array[DoubleReceivedMessage val]):
    CanonicalForm =>
    var results = ResultsList[I64]

    for m in received.values() do
      results.add(m.v)
    end
    results
