interface Message
  fun string(): String

trait SentMessage is Message

trait ReceivedMessage is Message
