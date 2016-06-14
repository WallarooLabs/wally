use "random"
use "time"

class GuidGenerator
  let _dice: Dice

  new create(seed: U64 = Time.micros()) =>
    _dice = Dice(MT(seed))

  fun ref apply(): U64 =>
    _dice(1, U64.max_value().u64()).u64()
