use ".."

actor Main
  new create(env: Env) =>
    VerifierCLI[IdentitySentMessage val, IdentityReceivedMessage val]
      .run(env, IdentityResultMapper, IdentitySentParser, 
        IdentityReceivedParser)

class IdentitySentMessage is SentMessage
  let ts: U64
  let v: I64

  new val create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun string(): String =>
    "(" + ts.string() + ", " + v.string() + ")"

class IdentityReceivedMessage is ReceivedMessage
  let ts: U64
  let v: I64

  new val create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun string(): String =>
    "(" + ts.string() + ", " + v.string() + ")"

class IdentitySentParser is SentParser[IdentitySentMessage val]
  let _messages: Array[IdentitySentMessage val] = 
    Array[IdentitySentMessage val]

  fun ref apply(value: Array[String] ref): None ? =>
    let timestamp = value(0).clone().strip().u64()
    let i = value(1).clone().strip().i64()
    _messages.push(IdentitySentMessage(timestamp, i))

  fun ref sent_messages(): Array[IdentitySentMessage val] =>
    _messages

class IdentityReceivedParser is ReceivedParser[IdentityReceivedMessage val]
  let _messages: Array[IdentityReceivedMessage val] = 
    Array[IdentityReceivedMessage val]

  fun ref apply(value: Array[String] ref): None ? =>
    let timestamp = value(0).clone().strip().u64()
    let i = value(1).clone().strip().i64()
    _messages.push(IdentityReceivedMessage(timestamp, i))

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
