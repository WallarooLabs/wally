/*

Copyright 2017 The Wallaroo Authors.

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

use "wallaroo/core/common"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"


primitive OutputProcessor
  fun apply[Out: Any val](next_runner: Runner, metric_name: String,
    pipeline_time_spent: U64,
    output: (Out | Array[Out] val | Array[(Out,U64)] val), key: Key,
    event_ts: U64, new_watermark_ts: U64, old_watermark_ts: U64,
    consumer_sender: TestableConsumerSender, router: Router,
    i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    computation_end: U64, metrics_id: U16, worker_ingress_ts: U64): (Bool, U64)
  =>
    """
    Send any outputs of a computation along to the next Runner, returning
    a tuple indicating if the message has finished processing and the last
    metrics-related timestamp.
    """
    match output
    | let o: Out val =>
      next_runner.run[Out](metric_name, pipeline_time_spent, o, key, event_ts,
        new_watermark_ts, consumer_sender, router, i_msg_uid, frac_ids,
        computation_end, metrics_id, worker_ingress_ts)
    | let os: Array[Out] val =>
      var this_is_finished = true
      var this_last_ts = computation_end

      var outputs_left = os.size()
      for (frac_id, o) in os.pairs() do
        outputs_left = outputs_left - 1

        let o_frac_ids = match frac_ids
        | None =>
          recover val
            Array[U32].init(frac_id.u32(), 1)
          end
        | let x: Array[U32 val] val =>
          recover val
            let z = Array[U32](x.size() + 1)
            for xi in x.values() do
              z.push(xi)
            end
            z.push(frac_id.u32())
            z
          end
        end

        // We don't want our downstream targets to trigger a window before it's
        // received all these messages, so we only send the updated output
        // watermark with the last of the messages.
        var next_watermark_ts =
          if outputs_left > 0 then old_watermark_ts else new_watermark_ts end

        // !TODO!: Is this using the correct metrics_id?  Or should we be
        // generating a new one here?
        (let f, let ts) = next_runner.run[Out](metric_name,
          pipeline_time_spent, o, key, event_ts, next_watermark_ts,
          consumer_sender, router, i_msg_uid, o_frac_ids,
          computation_end, metrics_id, worker_ingress_ts)

        // we are sending multiple messages, only mark this message as
        // finished if all are finished
        if (f == false) then
          this_is_finished = false
        end

        this_last_ts = ts
      end
      (this_is_finished, this_last_ts)
    // !TODO!: ONLY HERE UNTIL FRACTIONALIDs ARE REMOVED
    | let os: Array[(Out,U64)] val =>
      var this_is_finished = true
      var this_last_ts = computation_end

      var outputs_left = os.size()
      for (frac_id, (o, o_event_ts)) in os.pairs() do
        outputs_left = outputs_left - 1

        let o_frac_ids = match frac_ids
        | None =>
          recover val
            Array[U32].init(frac_id.u32(), 1)
          end
        | let x: Array[U32 val] val =>
          recover val
            let z = Array[U32](x.size() + 1)
            for xi in x.values() do
              z.push(xi)
            end
            z.push(frac_id.u32())
            z
          end
        end
        var next_watermark_ts =
          if outputs_left > 0 then old_watermark_ts else new_watermark_ts end
        // Supply the actual o_event_ts instead of the final output watermark
        // that we have received in the function call.
        (let f, let ts) = next_runner.run[Out](metric_name,
          pipeline_time_spent, o, key, o_event_ts, // This here is crucial.
          next_watermark_ts, consumer_sender, router, i_msg_uid, o_frac_ids,
          computation_end, metrics_id, worker_ingress_ts)

        if (f == false) then
          this_is_finished = false
        end

        this_last_ts = ts
      end
      (this_is_finished, this_last_ts)
    end
