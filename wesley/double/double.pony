use ".."

class DoubleSentMessage is SentMessage
  let ts: U64
  let v: I64

  new create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun string(): String =>
    String().append("(").append(ts.string()).append(", ").append(v.string()).append(")").clone()

class DoubleReceivedMessage is (ReceivedMessage & Equatable[DoubleReceivedMessage])
  let ts: U64
  let v: I64

  new create(ts': U64, v':I64) =>
    ts = ts'
    v = v'

  fun eq(that: DoubleReceivedMessage box): Bool =>
    this.v == that.v

  fun string(): String =>
    String().append("(").append(ts.string()).append(", ").append(v.string()).append(")").clone()

class DoubleSentMessages is SentMessages
  let messages: Array[DoubleSentMessage]

  new create() =>
    messages = Array[DoubleSentMessage]

  new from(messages': Array[DoubleSentMessage] ref) =>
     messages = Array[DoubleSentMessage]
     for m in messages'.values() do
       messages.push(m)
     end

  fun ref string(): String =>
    var acc = String()
    for m in messages.values() do
      acc.append(" ").append(m.string())
    end
    acc.clone()

class DoubleReceivedMessages is ReceivedMessages
  let _messages: Array[DoubleReceivedMessage] ref

  new create() =>
    _messages = Array[DoubleReceivedMessage]

  new from(messages: Array[DoubleReceivedMessage] ref) =>
    _messages = Array[DoubleReceivedMessage]
    for m in messages.values() do
      _messages.push(m)
    end

  fun _size(): USize => _messages.size()

  fun compare(that: ReceivedMessages): MatchStatus val =>
    match that
    | let that_double_received_messages: DoubleReceivedMessages =>
      if (this._size() == that_double_received_messages._size()) and (
        var equal = true
        try
          for (i, v) in _messages.pairs() do
            if (v != that_double_received_messages._messages(i)) and equal then
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

class DoubleSentVisitor is SentVisitor
  let _values: Array[DoubleSentMessage] ref = Array[DoubleSentMessage]()

  fun ref apply(value: Array[String] ref): None ? =>
    let timestamp = value(0).clone().strip().u64()
    let i = value(1).clone().strip().i64()
    _values.push(DoubleSentMessage(timestamp, i))

  fun ref build_sent_messages(): SentMessages =>
    DoubleSentMessages.from(_values)

class DoubleReceivedVisitor is ReceivedVisitor
  let _values: Array[DoubleReceivedMessage] ref = Array[DoubleReceivedMessage]()

  fun ref apply(value: Array[String] ref): None ? =>
    let timestamp = value(0).clone().strip().u64()
    let i = value(1).clone().strip().i64()
    _values.push(DoubleReceivedMessage(timestamp, i))

  fun ref build_received_messages(): ReceivedMessages =>
    DoubleReceivedMessages.from(_values)

class DoubleResultMapper is ResultMapper
  fun f(sent_messages: SentMessages): ReceivedMessages =>
    let messages: Array[DoubleSentMessage] ref = Array[DoubleSentMessage]
    var new_messages = Array[DoubleReceivedMessage]

    match sent_messages
    | let double_sent_messages: DoubleSentMessages =>
      for m in double_sent_messages.messages.values() do
        new_messages.push(DoubleReceivedMessage(m.ts, m.v * 2))
      end
    else
      None
    end
    DoubleReceivedMessages.from(new_messages)

actor Main
  new create(env: Env) =>
    VerifierCLI.run(env, DoubleResultMapper, DoubleSentVisitor, DoubleReceivedVisitor)
