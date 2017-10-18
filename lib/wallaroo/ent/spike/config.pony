/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "assert"
use "time"

class val SpikeConfig
  let drop: Bool
  let seed: U64
  let prob: F64
  let margin: USize

  new val create(drop': Bool = true, prob': (F64 | None) = 0.001,
    margin': (USize | None) = 10, seed': (U64 | None) = None) ?
  =>
    drop = drop'
    match prob'
    | let arg: F64 =>
      Fact(arg <= 1, "prob' must be between 0 and 1")?
      prob = arg
    else
      prob = 0.001
    end
    match seed'
    | let arg: U64 => seed = arg
    else
      seed = Time.millis()
    end
    match margin'
    | let arg: USize => margin = arg
    else
      margin = 10
    end
