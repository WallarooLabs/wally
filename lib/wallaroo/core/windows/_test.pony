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

use "ponytest"
use "promises"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo_labs/time"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    // // Windows
    test(_TestTumblingWindows)
    test(_TestMessageAssignmentToTumblingWindows)
    test(_TestOutputWatermarkTsIsJustBeforeNextWindowStart)
    test(_TestOnTimeoutWatermarkTsIsJustBeforeNextWindowStart)
    test(_Test0) // !@
    test(_Test1) // !@
    test(_Test2) // !@
    test(_TestTumblingWindowsTimeoutTrigger)
    test(_TestSlidingWindows)
    test(_TestSlidingWindowsNoDelay)
    test(_TestSlidingWindowsOutOfOrder)
    test(_TestSlidingWindowsGCD)
    test(_TestSlidingWindowsLateData)
    test(_TestSlidingWindowsEarlyData)
    test(_TestSlidingWindowsStragglers)
    test(_TestSlidingWindowsStragglersSequence)
    test(_TestSlidingWindowsSequence)
    test(_TestCountWindows)

    // Expand Windows
    test(_TestExpandSlidingWindow)

    // // Watermarks
    test(_TestTimeoutTriggerWatermark)
    test(_TestStageWatermarks)
