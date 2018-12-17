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

use "wallaroo/core/state"
use "wallaroo_labs/mort"


trait WindowsPhase[In: Any val, Out: Any val, Acc: State ref]
  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)

  fun ref attempt_to_trigger(watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)

  fun check_panes_increasing(): Bool =>
    false

class EmptyWindowsPhase[In: Any val, Out: Any val, Acc: State ref] is
  WindowsPhase[In, Out, Acc]
  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)
  =>
    Fail()
    (None, 0)

  fun ref attempt_to_trigger(watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)
  =>
    Fail()
    (None, 0)

class InitialWindowsPhase[In: Any val, Out: Any val, Acc: State ref] is
  WindowsPhase[In, Out, Acc]
  let _windows: Windows[In, Out, Acc]
  let _windows_wrapper_builder: WindowsWrapperBuilder[In, Out, Acc]

  new create(w: Windows[In, Out, Acc],
    wwb: WindowsWrapperBuilder[In, Out, Acc])
  =>
    _windows = w
    _windows_wrapper_builder = wwb

  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)
  =>
    let wrapper = _windows_wrapper_builder(watermark_ts)
    _windows._initial_apply(input, event_ts, watermark_ts, wrapper)

  fun ref attempt_to_trigger(watermark_ts: U64):
    ((Out | Array[Out] val | None), U64)
  =>
    let wrapper = _windows_wrapper_builder(watermark_ts)
    _windows._initial_attempt_to_trigger(watermark_ts, wrapper)

class ProcessingWindowsPhase[In: Any val, Out: Any val, Acc: State ref] is
  WindowsPhase[In, Out, Acc]
  let _windows_wrapper: WindowsWrapper[In, Out, Acc]

  new create(ww: WindowsWrapper[In, Out, Acc]) =>
    _windows_wrapper = ww

  fun ref apply(input: In, event_ts: U64, watermark_ts: U64):
    (Array[Out] val, U64)
  =>
    _windows_wrapper.apply(input, event_ts, watermark_ts)

  fun ref attempt_to_trigger(watermark_ts: U64): (Array[Out] val, U64) =>
    _windows_wrapper.attempt_to_trigger(watermark_ts)

  fun check_panes_increasing(): Bool =>
    _windows_wrapper.check_panes_increasing()
