use "buffered"
use "time"
<<<<<<< HEAD
=======
use "sendence/epoch"
>>>>>>> master
use "../metrics"

actor Step
  let _runner: Runner

  new create(runner: Runner iso) =>
    _runner = consume runner

  be run[In: Any val](metric_name: String, source_ts: U64, input: In) =>
    _runner.run[In](metric_name, source_ts, input)

