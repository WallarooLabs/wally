/*

Copyright 2018 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "time"
use "wallaroo/core/common"
use "wallaroo/core/metrics"
use "wallaroo/core/windows"


trait TimeoutTriggeringRunner
  fun ref set_triggers(stt: StepTimeoutTrigger, watermarks: StageWatermarks)
  fun ref on_timeout(producer_id: RoutingId, step: Step ref,
    router: Router, metrics_reporter: MetricsReporter ref,
    watermarks: StageWatermarks)

class StepTimeoutTrigger
  let _step: Step ref

  new create(s: Step ref) =>
    _step = s

  fun ref set_timeout(t: U64) =>
    _step.set_timeout(t)

class StepTimeoutNotify is TimerNotify
  let _step: Step

  new iso create(s: Step) =>
    _step = s

  fun ref apply(timer: Timer, count: U64): Bool =>
    _step.trigger_timeout()
    false
