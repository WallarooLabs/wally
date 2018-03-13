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

use "time"
use "wallaroo_labs/guid"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

class TypedRoute[In: Any val] is Route
  """
  Relationship between a single producer and a single consumer.
  """
  // route 0 is used for filtered messages
  let _route_id: U64 = 1 + RouteIdGenerator()
  var _step_type: String = ""
  let _step: Producer ref
  let _consumer: Consumer
  let _metrics_reporter: MetricsReporter
  var _route: RouteLogic = _EmptyRouteLogic

  new create(step: Producer ref, consumer: Consumer,
    metrics_reporter: MetricsReporter ref)
  =>
    _step = step
    _consumer = consumer
    _metrics_reporter = metrics_reporter
    _route = _RouteLogic(step, consumer, "Typed")

  fun ref application_created() =>
    _consumer.register_producer(_step)

  fun ref application_initialized(step_type: String) =>
    _step_type = step_type
    _route.application_initialized(step_type)

  fun id(): U64 =>
    _route_id

  fun ref dispose() =>
    _route.dispose()

  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    ifdef "trace" then
      @printf[I32]("--Rcvd msg at Route (%s)\n".cstring(),
        _step_type.cstring())
    end
    match data
    | let input: In =>
      ifdef debug then
        match _step
        | let source: TCPSource ref =>
          Invariant(not source.is_muted())
        end
      end

      _send_message_on_route(metric_name, pipeline_time_spent, input, cfp,
        msg_uid, frac_ids, latest_ts, metrics_id, worker_ingress_ts)
      true
    else
      Fail()
      true
    end

  fun ref forward(delivery_msg: ReplayableDeliveryMsg,
    pipeline_time_spent: U64, cfp: Producer ref,
    latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64)
  =>
    // Forward should never be called on a TypedRoute
    Fail()
    true

  fun ref _send_message_on_route(metric_name: String, pipeline_time_spent: U64,
    input: In, cfp: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    let o_seq_id = cfp.next_sequence_id()

    let my_latest_ts = ifdef "detailed-metrics" then
        Time.nanos()
      else
        latest_ts
      end

    let new_metrics_id = ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(metric_name,
          "Before send to next step via behavior", metrics_id,
          latest_ts, my_latest_ts)
        metrics_id + 1
      else
        metrics_id
      end

    _consumer.run[In](metric_name,
      pipeline_time_spent,
      input,
      cfp,
      msg_uid,
      frac_ids,
      o_seq_id,
      _route_id,
      my_latest_ts,
      new_metrics_id,
      worker_ingress_ts)

    ifdef "trace" then
      @printf[I32]("Sent msg from Route (%s)\n".cstring(),
        _step_type.cstring())
    end

    ifdef "resilience" then
      cfp.bookkeeping(_route_id, o_seq_id)
    end

  fun ref request_ack() =>
    _consumer.request_ack()

  //!@
  fun ref report_status(code: ReportStatusCode) =>
    _consumer.report_status(code)

  fun ref request_finished_ack(request_id: RequestId, requester_id: StepId,
    requester: FinishedAckRequester)
  =>
    // @printf[I32]("!@ request_finished_ack TYPED ROUTE\n".cstring())
    _consumer.request_finished_ack(request_id, requester_id, requester)

  fun ref request_finished_ack_complete(requester_id: StepId,
    requester: FinishedAckRequester)
  =>
    // @printf[I32]("!@ request_finished_ack_complete TYPED ROUTE\n".cstring())
    _consumer.request_finished_ack_complete(requester_id, requester)

  fun ref receive_finished_ack(request_id: RequestId) =>
    _step.receive_finished_ack(request_id)
