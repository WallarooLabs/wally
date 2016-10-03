use "random"
use "time"

class GuidGenerator
  let _rand: Random

  new create(seed: U64 = Time.nanos()) =>
    _rand = MT(seed)

  fun ref apply(): U64 =>
    _rand.next()

  fun ref u128(): U128 =>
    _rand.next().u128() or (_rand.next().u128() << 64)
