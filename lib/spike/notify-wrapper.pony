use "net"
use "time"

class SpikeConfig
  let delay: Bool
  let drop: Bool
  let seed: U64

  new val create(delay': Bool, drop': Bool, seed': U64 = Time.millis()) =>
    delay = delay'
    drop = drop'
    seed = seed'

primitive SpikeWrapper
  fun apply(letter: TCPConnectionNotify iso, config: SpikeConfig val)
    : TCPConnectionNotify iso^ =>
    var notify: TCPConnectionNotify iso = consume letter
    if config.delay then
      notify = DelayReceived(consume notify)
    end
    if config.drop then
      notify = DropConnection(config.seed, 25, consume notify)
    end
    consume notify
