/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/core/common"


trait tag BarrierReceiver
  be receive_barrier(step_id: StepId, producer: Producer,
    barrier_token: BarrierToken)
  fun ref barrier_complete(barrier_token: BarrierToken)
