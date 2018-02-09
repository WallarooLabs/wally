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

use "wallaroo_labs/guid"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo_labs/mort"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

class BoundaryRoute is Route
  """
  Relationship between a single producer and a single consumer.
  """
  // route 0 is used for filtered messages
  let _route_id: U64 = 1 + RouteIdGenerator()
  var _step_type: String = ""
  let _step: Producer ref
  let _consumer: OutgoingBoundary
  let _metrics_reporter: MetricsReporter
  var _route: RouteLogic = _EmptyRouteLogic

  new create(step: Producer ref, consumer: OutgoingBoundary,
    metrics_reporter: MetricsReporter ref)
  =>
    _step = step
    _consumer = consumer
    _metrics_reporter = metrics_reporter
    _route = _RouteLogic(step, consumer, "Boundary")

  fun ref application_created() =>
    _consumer.register_producer(_step)

  fun ref application_initialized(step_type: String) =>
    _step_type = step_type
    _route.application_initialized(step_type)

  fun id(): U64 =>
    _route_id

  fun ref dispose() =>
    None

  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref, msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    // Run should never be called on a BoundaryRoute
    Fail()

  fun ref forward(delivery_msg: ReplayableDeliveryMsg,
    pipeline_time_spent: U64, cfp: Producer ref,
    latest_ts: U64, metrics_id: U16,
    metric_name: String, worker_ingress_ts: U64)
  =>
    ifdef debug then
      match _step
      | let source: TCPSource ref =>
        Invariant(not source.is_muted())
      end
    end
    ifdef "trace" then
      @printf[I32]("Rcvd msg at BoundaryRoute (%s)\n".cstring(),
        _step_type.cstring())
    end
    _send_message_on_route(delivery_msg,
      pipeline_time_spent,
      cfp,
      latest_ts,
      metrics_id,
      metric_name,
      worker_ingress_ts)

  fun ref _send_message_on_route(delivery_msg: ReplayableDeliveryMsg,
    pipeline_time_spent: U64, cfp: Producer ref,
    latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64)
  =>
    let o_seq_id = cfp.next_sequence_id()

    _consumer.forward(delivery_msg,
      pipeline_time_spent,
      cfp,
      o_seq_id,
      _route_id,
      latest_ts,
      metrics_id,
      worker_ingress_ts)

    ifdef "resilience" then
      cfp.bookkeeping(_route_id, o_seq_id)
    end

  fun ref request_ack() =>
    _consumer.request_ack()
