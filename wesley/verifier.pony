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
  new val create(expected: MatchStatus val, actual: MatchStatus val) =>
    _exitmessage = "Expected ".add(expected.expected()).add(", and ").add(actual.actual())
  fun exitcode(): I32 => 0
  fun exitmessage(): String =>
    _exitmessage

class Fail is PassFail
  let _exitmessage: String
  new val create(expected: MatchStatus val, actual: MatchStatus val) =>
    _exitmessage = "Expected ".add(expected.expected()).add(", but ").add(actual.actual())
  fun exitcode(): I32 => 1
  fun exitmessage(): String =>
    _exitmessage

interface ResultMapper
  fun f(sent_messages: SentMessages): ReceivedMessages

interface Message
  fun string(): String

interface Messages

interface SentMessage is Message
interface ReceivedMessage is Message

interface SentMessages is Messages
interface ReceivedMessages is Messages
  fun compare(that: ReceivedMessages): MatchStatus val

interface SentVisitor is CSVVisitor
  fun ref build_sent_messages(): SentMessages

interface ReceivedVisitor is CSVVisitor
  fun ref build_received_messages(): ReceivedMessages

class Verifier
  let _sent_messages: SentMessages 
  let _received_messages: ReceivedMessages
  let _result_mapper: ResultMapper
  let _expected_match_result: MatchStatus val
  
  new create(sent_messages: SentMessages, received_messages: ReceivedMessages, result_mapper: ResultMapper, expected_match_result: MatchStatus val) =>
    _sent_messages = sent_messages
    _received_messages = received_messages
    _result_mapper = result_mapper
    _expected_match_result = expected_match_result

  fun ref test(): PassFail val =>
    let expected_messages = _result_mapper.f(_sent_messages)
    let actual_match_result = expected_messages.compare(_received_messages)
    if _expected_match_result is actual_match_result then
      Pass(_expected_match_result, actual_match_result)
    else
      Fail(_expected_match_result, actual_match_result)
    end
    