use "assert"
use "time"
use "wallaroo/network"

class val SpikeConfig
  let drop: Bool
  let seed: U64
  let prob: U64

  new val create(drop': Bool, prob': (U64 | None) = 10,
    seed': (U64 | None) = None) ?
  =>
    drop = drop'
    match prob'
    | let arg: U64 =>
      Fact(arg <= 100, "prob' must be between 0 and 100")
      prob = arg
    else
      prob = 10
    end
    match seed'
    | let arg: U64 => seed = arg
    else
      seed = Time.millis()
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
