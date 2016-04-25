use ".."

class WordcountSentMessage is SentMessage
  let ts: U64
  let text: String

  new create(ts': U64, text':String) =>
    ts = ts'
    text = text'

  fun string(): String =>
    String().append("(").append(ts.string()).append(", ").append(text).append(")").clone()

class WordcountReceivedMessage is (ReceivedMessage & Equatable[WordcountReceivedMessage])
  let ts: U64
  let word: String
  let count: U64

  new create(ts': U64, word': String, count': U64) =>
    ts = ts'
    word = word'
    count = count'

  fun eq(that: WordcountReceivedMessage box): Bool =>
    (this.word == that.word) and (this.count == that.count)

  fun string(): String =>
    String().append("(").append(ts.string()).append(", ").append(word).append(": ").append(count.string()).append(")").clone()

class WordcountSentMessages is SentMessages
  let wc: WordCounter = WordCounter
  
  new create() =>
    this

  new from(messages': Array[WordcountSentMessage] ref) =>
     for m in messages'.values() do
       wc.update_from_string(m.text)
     end
     this

  fun ref string(): String =>
    var acc = String()
    for (word, count) in wc.counts.pairs() do
      acc.append(", ").append(word).append(":").append(count.string())
    end
    acc.clone()

class WordcountReceivedMessages is ReceivedMessages
  let wc: WordCounter = WordCounter

  new create() =>
    this

  new from(messages: Array[WordcountReceivedMessage] ref) =>
    for m in messages.values() do
      wc.update(m.word, m.count)
    end
    this
  
  new from_wordcounter(wordcounter: WordCounter) =>
    let m = wordcounter.counts.clone()
    wc.load_from_map(m)

  fun _size(): USize => 
    wc.counts.size()

  fun compare(that: ReceivedMessages): MatchStatus val =>
    try
      if wc == (that as WordcountReceivedMessages).wc 
      then ResultsMatch 
      else ResultsDoNotMatch 
      end
    else
      ResultsDoNotMatch
    end

  fun ref string(): String =>
    var acc = String()
    for (word, count) in wc.counts.pairs() do
      acc.append(", ").append(word).append(":").append(count.string())
    end
    acc.clone()


class WordcountSentVisitor is SentVisitor
  let _values: Array[WordcountSentMessage] ref = Array[WordcountSentMessage]()

  fun ref apply(value: Array[String] ref): None ? =>
    let timestamp = value(0).clone().strip().u64()
    let text = value(1).clone()
    _values.push(WordcountSentMessage(timestamp, consume text))

  fun ref build_sent_messages(): SentMessages =>
    WordcountSentMessages.from(_values)


class WordcountReceivedVisitor is ReceivedVisitor
  let _values: Array[WordcountReceivedMessage] ref = Array[WordcountReceivedMessage]()

  fun ref apply(value: Array[String] ref): None ? =>
    let timestamp = value(0).clone().strip().u64()
    let word = value(1).clone()
    let count = value(2).clone().strip().u64()
    _values.push(WordcountReceivedMessage(timestamp, consume word, count))

  fun ref build_received_messages(): ReceivedMessages =>
    WordcountReceivedMessages.from(_values)


class WordcountResultMapper is ResultMapper
  fun f(sent_messages: SentMessages): ReceivedMessages =>

    WordcountReceivedMessages.from_wordcounter(WordCounter)


actor Main
  new create(env: Env) =>
    VerifierCLI.run(env, WordcountResultMapper, WordcountSentVisitor, WordcountReceivedVisitor)
