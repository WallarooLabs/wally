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
    VerifierCLI[IdentitySentMessage val, IdentityReceivedMessage val]
      .run(env, "Identity", IdentityResultMapper, IdentitySentParser,
        IdentityReceivedParser)

class IdentitySentMessage
  let ts: U64
  let v: I64

  new val create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun string(): String iso^ =>
    ("(" + ts.string() + ", " + v.string() + ")").clone()

class IdentityReceivedMessage
  let ts: U64
  let v: I64

  new val create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun string(): String iso^ =>
    ("(" + ts.string() + ", " + v.string() + ")").clone()

class IdentitySentParser is SentParser[IdentitySentMessage val]
  let _messages: Array[IdentitySentMessage val] =
    Array[IdentitySentMessage val]

  fun ref apply(fields: Array[String] val): None ? =>
    let timestamp = fields(0).clone().strip().u64()
    let i = fields(1).clone().strip().i64()
    _messages.push(IdentitySentMessage(timestamp, i))

  fun ref sent_messages(): Array[IdentitySentMessage val] =>
    _messages

class IdentityReceivedParser is ReceivedParser[IdentityReceivedMessage val]
  let _messages: Array[IdentityReceivedMessage val] =
    Array[IdentityReceivedMessage val]

  fun ref apply(fields: Array[String] val): None ? =>
    try
      let timestamp = fields(0).clone().strip().u64()
      let i = fields(1).clone().strip().i64()
      _messages.push(IdentityReceivedMessage(timestamp, i))
    else
      @printf[I32]("Parser problem!\n".cstring())
      error
    end

  fun ref received_messages(): Array[IdentityReceivedMessage val] =>
    _messages

class IdentityResultMapper is
  ResultMapper[IdentitySentMessage val, IdentityReceivedMessage val]

  fun sent_transform(sent: Array[IdentitySentMessage val]):
    CanonicalForm =>
    var results = ResultsList[I64]

    for m in sent.values() do
      results.add(m.v)
    end
    results

  fun received_transform(received: Array[IdentityReceivedMessage val]):
    CanonicalForm =>
    var results = ResultsList[I64]

    for m in received.values() do
      results.add(m.v)
    end
    results
