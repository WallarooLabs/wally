use "time"

primitive WallClock
  fun nanoseconds(): U64 =>
    let wall = Time.now()
    ((wall._1 * 1000000000) + wall._2).u64()

  fun microseconds(): U64 =>
    let wall = Time.now()
    ((wall._1 * 1000000) + (wall._2/1000)).u64()

  fun milliseconds(): U64 =>
    let wall = Time.now()
    ((wall._1 * 1000) + (wall._2/1000000)).u64()

  fun seconds(): U64 =>
    let wall = Time.now()
    wall._1.u64()