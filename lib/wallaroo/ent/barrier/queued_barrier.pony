/*

Copyright 2018 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/core/common"
use "wallaroo/core/topology"


trait BarrierProcessor
  fun ref process_barrier(step_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)

class val QueuedBarrier
  let _input_id: RoutingId
  let _producer: Producer
  let _barrier_token: BarrierToken

  new val create(input_id: RoutingId, producer: Producer,
    barrier_token: BarrierToken)
  =>
    _input_id = input_id
    _producer = producer
    _barrier_token = barrier_token

  fun inject_barrier(b_processor: BarrierProcessor ref) =>
    b_processor.process_barrier(_input_id, _producer, _barrier_token)
