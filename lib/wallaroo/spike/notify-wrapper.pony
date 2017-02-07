use "time"
use "wallaroo/network"

class SpikeConfig
  let delay: Bool
  let drop: Bool
  let seed: U64

  new val create(delay': Bool, drop': Bool, seed': U64 = Time.millis()) =>
    delay = delay'
    drop = drop'
    seed = seed'

primitive SpikeWrapper
  fun apply(letter: WallarooOutgoingNetworkActorNotify iso,
    config: SpikeConfig val): WallarooOutgoingNetworkActorNotify iso^
  =>
    var notify: WallarooOutgoingNetworkActorNotify iso = consume letter
   /* if config.delay then
      notify = DelayReceived(consume notify)
    end*/
    if config.drop then
      notify = DropConnection(config.seed, 10, consume notify)
    end

    consume notify
