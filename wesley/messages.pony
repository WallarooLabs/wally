interface Message
  fun string(): String

trait Messages

trait SentMessage is Message

trait ReceivedMessage is Message
