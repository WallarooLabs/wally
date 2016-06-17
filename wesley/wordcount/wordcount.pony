use ".."

actor Main
  new create(env: Env) =>
    VerifierCLI[WordcountSentMessage val, WordcountReceivedMessage val]
      .run(env, WordcountResultMapper, WordcountSentParser, 
        WordcountReceivedParser)

class WordcountSentMessage
  let ts: U64
  let text: String

  new val create(ts': U64, text':String) =>
    ts = ts'
    text = text'

  fun string(fmt: FormatSettings = FormatSettingsDefault): String iso^ =>
    ("(" + ts.string() + ", " + text + ")").clone()

class WordcountReceivedMessage
  let ts: U64
  let word: String
  let count: U64

  new val create(ts': U64, word': String, count': U64) =>
    ts = ts'
    word = word'
    count = count'

  fun string(fmt: FormatSettings = FormatSettingsDefault): String iso^ =>
    ("(" + ts.string() + ", " + word + ": " + count.string() + ")").clone()

class WordcountSentParser is SentParser[WordcountSentMessage val]
  let _messages: Array[WordcountSentMessage val] = 
    Array[WordcountSentMessage val]

  fun fn(): USize => 2

  fun ref apply(value: Array[String] ref) ? =>
    let timestamp = value(0).clone().strip().u64()
    let text = value(1)
    _messages.push(WordcountSentMessage(timestamp, text))

  fun ref sent_messages(): Array[WordcountSentMessage val] =>
    _messages

class WordcountReceivedParser is ReceivedParser[WordcountReceivedMessage val]
  let _messages: Array[WordcountReceivedMessage val] =
    Array[WordcountReceivedMessage val]

  fun ref apply(value: Array[String] ref) ? =>
    let timestamp = value(0).clone().strip().u64()
    let word = value(1)
    let count = value(2).clone().strip().u64()
    _messages.push(WordcountReceivedMessage(timestamp, consume word, count))

  fun ref received_messages(): Array[WordcountReceivedMessage val] =>
    _messages

class WordcountResultMapper is ResultMapper[WordcountSentMessage val,
  WordcountReceivedMessage val]

  fun sent_transform(sent: Array[WordcountSentMessage val]): 
    CanonicalForm =>
    var wc = WordCounter 

    for m in sent.values() do
      wc.update_from_string(m.text)
    end
    wc

  fun received_transform(received: Array[WordcountReceivedMessage val]): 
    CanonicalForm =>
    var wc = WordCounter 

    for m in received.values() do
      try 
        if wc(m.word) < m.count then
          wc(m.word) = m.count
        end
      else
        wc(m.word) = m.count
      end
    end
    wc
