use ".."

class IdentitySentMessage is SentMessage
  let ts: U64
  let v: I64

  new create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun string(): String =>
    String().append("(").append(ts.string()).append(", ").append(v.string()).append(")").clone()

class IdentityReceivedMessage is (ReceivedMessage & Equatable[IdentityReceivedMessage])
  let ts: U64
  let v: I64

  new create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun eq(that: IdentityReceivedMessage box): Bool =>
    this.v == that.v

  fun string(): String =>
    String().append("(").append(ts.string()).append(", ").append(v.string()).append(")").clone()

class IdentitySentMessages is SentMessages
  let messages: Array[IdentitySentMessage]

  new create() =>
    messages = Array[IdentitySentMessage]

  new from(messages': Array[IdentitySentMessage] ref) =>
     messages = Array[IdentitySentMessage]
     for m in messages'.values() do
       messages.push(m)
     end

  fun ref string(): String =>
    var acc = String()
    for m in messages.values() do
      acc.append(" ").append(m.string())
    end
    acc.clone()

class IdentityReceivedMessages is ReceivedMessages
  let _messages: Array[IdentityReceivedMessage] ref

  new create() =>
    _messages = Array[IdentityReceivedMessage]

  new from(messages: Array[IdentityReceivedMessage] ref) =>
    _messages = Array[IdentityReceivedMessage]
    for m in messages.values() do
      _messages.push(m)
    end

  fun _size(): USize => _messages.size()

  fun compare(that: ReceivedMessages): MatchStatus val =>
    match that
    | let that_identity_received_messages: IdentityReceivedMessages =>
      if (this._size() == that_identity_received_messages._size()) and (
        var equal = true
        try
          for (i, v) in _messages.pairs() do
            if (v != that_identity_received_messages._messages(i)) and equal then
              equal = false
            end
          end
        end
      equal) then
        ResultsMatch
      else
        ResultsDoNotMatch
      end
    else
      ResultsDoNotMatch
    end

  fun ref string(): String =>
    var acc = String()
    for m in _messages.values() do
      acc.append(" ").append(m.string())
    end
    acc.clone()

class IdentitySentVisitor is SentVisitor
  let _values: Array[IdentitySentMessage] ref = Array[IdentitySentMessage]()

  fun ref apply(value: Array[String] ref): None ? =>
    let timestamp = value(0).clone().strip().u64()
    let i = value(1).clone().strip().i64()
    _values.push(IdentitySentMessage(timestamp, i))

  fun ref build_sent_messages(): SentMessages =>
    IdentitySentMessages.from(_values)

class IdentityReceivedVisitor is ReceivedVisitor
  let _values: Array[IdentityReceivedMessage] ref = Array[IdentityReceivedMessage]()

  fun ref apply(value: Array[String] ref): None ? =>
    let timestamp = value(0).clone().strip().u64()
    let i = value(1).clone().strip().i64()
    _values.push(IdentityReceivedMessage(timestamp, i))

  fun ref build_received_messages(): ReceivedMessages =>
    IdentityReceivedMessages.from(_values)

class IdentityResultMapper is ResultMapper
  fun f(sent_messages: SentMessages): ReceivedMessages =>
    let messages: Array[IdentitySentMessage] ref = Array[IdentitySentMessage]
    var new_messages = Array[IdentityReceivedMessage]

    match sent_messages
    | let identity_sent_messages: IdentitySentMessages =>
      for m in identity_sent_messages.messages.values() do
        new_messages.push(IdentityReceivedMessage(m.ts, m.v))
      end
    else
      None
    end
    IdentityReceivedMessages.from(new_messages)

actor Main
  new create(env: Env) =>
    VerifierCLI.run(env, IdentityResultMapper, IdentitySentVisitor, IdentityReceivedVisitor)
