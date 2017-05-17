interface Verifier
  fun ref test(): PassFail val

class StatelessVerifier[S: Message val, R: Message val]
  let _sent_messages: Array[S]
  let _received_messages: Array[R]
  let _result_mapper: ResultMapper[S, R]
  let _expected_match_result: MatchStatus val

  new create(sent_messages: Array[S],
    received_messages: Array[R],
    result_mapper: ResultMapper[S, R],
    expected_match_result: MatchStatus val)
  =>
    _sent_messages = sent_messages
    _received_messages = received_messages
    _result_mapper = result_mapper
    _expected_match_result = expected_match_result

  fun ref test(): PassFail val =>
    let expected = _result_mapper.sent_transform(_sent_messages)
    let actual = _result_mapper.received_transform(_received_messages)
    (let actual_match_result, let resultmessage) = expected.compare(actual)
    if _expected_match_result is actual_match_result then
      Pass(_expected_match_result, actual_match_result, resultmessage)
    else
      Fail(_expected_match_result, actual_match_result, resultmessage)
    end

class StatefulVerifier[S: Message val, R: Message val,
  I: Message val, St: Any ref]
  let _init_messages: Array[I]
  let _sent_messages: Array[S]
  let _received_messages: Array[R]
  let _result_mapper: StatefulResultMapper[S, R, I, St]
  let _expected_match_result: MatchStatus val

  new create(init_messages: Array[I],
    sent_messages: Array[S],
    received_messages: Array[R],
    result_mapper: StatefulResultMapper[S, R, I, St],
    expected_match_result: MatchStatus val)
  =>
    _init_messages = init_messages
    _sent_messages = sent_messages
    _received_messages = received_messages
    _result_mapper = result_mapper
    _expected_match_result = expected_match_result

  fun ref test(): PassFail val =>
    let init_state: St = _result_mapper.init_transform(_init_messages)
    let expected = _result_mapper.sent_transform(_sent_messages,
      init_state)
    let actual = _result_mapper.received_transform(_received_messages)
    (let actual_match_result, let resultmessage) = expected.compare(actual)
    if _expected_match_result is actual_match_result then
      Pass(_expected_match_result, actual_match_result, resultmessage)
    else
      Fail(_expected_match_result, actual_match_result, resultmessage)
    end

interface CanonicalForm
  fun compare(that: CanonicalForm): (MatchStatus val, String)

// For when you need an ordered list of results
class ResultsList[V: (Equatable[V] #read & Stringable)] is CanonicalForm
  let results: Array[V] = Array[V]

  fun ref add(r: V) => results.push(r)

  fun compare(that: CanonicalForm): (MatchStatus val, String) =>
    match that
    | let rl: ResultsList[V] =>
      if (results.size() == rl.results.size()) then
        try
          for (i, v) in results.pairs() do
            if (v != rl.results(i)) then
              let msg = v.string() + " expected, " + rl.results(i).string()
                + " received."
              return (ResultsDoNotMatch, msg)
            end
          end
        end
        return (ResultsMatch, "")
      else
        (ResultsDoNotMatch, "Result sizes do not match up.")
      end
    else
      (ResultsDoNotMatch, "")
    end

trait ResultMapper[S: Message val, R: Message val]
  fun sent_transform(sent: Array[S]): CanonicalForm
  fun received_transform(received: Array[R]): CanonicalForm

trait StatefulResultMapper[S: Message val, R: Message val,
  I: Message val, St: Any ref]
  fun init_transform(init: Array[I]): St
  fun sent_transform(sent: Array[S], state: St): CanonicalForm
  fun received_transform(received: Array[R]): CanonicalForm

trait SentParser[S: Message val] is TextMessageFileParser
  fun ref sent_messages(): Array[S]

trait ReceivedParser[R: Message val] is MessageFileParser
  fun ref received_messages(): Array[R]

trait InitializationParser[I: Message val] is TextMessageFileParser
  fun ref initialization_messages(): Array[I]

interface MatchStatus
  fun expected(): String
  fun actual(): String

primitive ResultsMatch is MatchStatus
  fun expected(): String val => "results to match"
  fun actual(): String val => "results match"

primitive ResultsDoNotMatch is MatchStatus
  fun expected(): String val => "results to not match"
  fun actual(): String val => "results do not match"

interface PassFail
  fun exitcode(): I32
  fun exitmessage(): String

class Pass is PassFail
  let _exitmessage: String
  new val create(expected: MatchStatus val, actual: MatchStatus val,
    resultmessage: String) =>
    _exitmessage = "Expected ".add(expected.expected()).add(", and ")
      .add(actual.actual()).add("\n").add(resultmessage)
  fun exitcode(): I32 => 0
  fun exitmessage(): String =>
    _exitmessage

class Fail is PassFail
  let _exitmessage: String
  new val create(expected: MatchStatus val, actual: MatchStatus val,
    resultmessage: String) =>
    _exitmessage = "Expected ".add(expected.expected()).add(", but ")
      .add(actual.actual()).add("\n").add(resultmessage)
  fun exitcode(): I32 => 1
  fun exitmessage(): String =>
    _exitmessage

