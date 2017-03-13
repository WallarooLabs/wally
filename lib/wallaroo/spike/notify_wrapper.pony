use "time"
use "wallaroo/network"

class SpikeConfig
  let drop: Bool
  let seed: U64
  let prob: U64

  new val create(drop': Bool, prob': U64 = 10, seed': U64 = Time.millis()) =>
    drop = drop'
    seed = seed'
    if prob' > 100 then
      prob = 100
    else
      prob = prob'
    end

primitive SpikeWrapper
  fun apply(letter: WallarooOutgoingNetworkActorNotify iso,
    config: SpikeConfig val): WallarooOutgoingNetworkActorNotify iso^
  =>
    var notify: WallarooOutgoingNetworkActorNotify iso = consume letter
    if config.drop then
      notify = DropConnection(config.seed, config.prob, consume notify)
    end

    consume notify
