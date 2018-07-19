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

use "wallaroo/core/common"
use "wallaroo/core/messages"
use "wallaroo/core/topology"
use "wallaroo/ent/data_receiver"
use "wallaroo_labs/mort"

trait Rerouter
  fun router(): (Router | DataRouter)

  fun ref reroute(producer: Producer ref,
    route_args: RoutingArguments)
  =>
    route_args.route_with(router(), producer)

trait val RoutingArguments
  fun val apply(rerouter: Rerouter, producer: Producer ref)
  fun val route_with(router: (Router | DataRouter), producer: Producer ref)

class val TypedRoutingArguments[D: Any val] is RoutingArguments
  let _metric_name: String
  let _pipeline_time_spent: U64
  let _data: D
  let _producer_id: RoutingId
  let _i_msg_uid: MsgId
  let _frac_ids: FractionalMessageId
  let _latest_ts: U64
  let _metrics_id: U16
  let _worker_ingress_ts: U64

  new val create(metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: RoutingId, i_msg_uid: MsgId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _metric_name = metric_name
    _pipeline_time_spent = pipeline_time_spent
    _data = data
    _producer_id = producer_id
    _i_msg_uid = i_msg_uid
    _frac_ids = frac_ids
    _latest_ts = latest_ts
    _metrics_id = metrics_id
    _worker_ingress_ts = worker_ingress_ts

  fun val apply(rerouter: Rerouter, producer: Producer ref) =>
    rerouter.reroute(producer, this)

  fun val route_with(router: (Router | DataRouter), producer: Producer ref) =>
    // !@ this doesn't correctly capture times for calculating latencies,
    // so what do we want to do about this?
    match router
    | let r: Router =>
      r.route[D](_metric_name, _pipeline_time_spent, _data, _producer_id,
        producer, _i_msg_uid, _frac_ids, _latest_ts, _metrics_id,
        _worker_ingress_ts)
    else
      @printf[I32]("Router failed to reroute message.\n".cstring())
      Fail()
    end

class val TypedDataRoutingArguments[D: Any val] is RoutingArguments
  let _metric_name: String
  let _pipeline_time_spent: U64
  let _data: D
  let _producer_id: RoutingId
  let _seq_id: SeqId
  let _frac_ids: FractionalMessageId
  let _latest_ts: U64
  let _metrics_id: U16
  let _worker_ingress_ts: U64

  new val create(metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: RoutingId, seq_id: SeqId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _metric_name = metric_name
    _pipeline_time_spent = pipeline_time_spent
    _data = data
    _producer_id = producer_id
    _seq_id = seq_id
    _frac_ids = frac_ids
    _latest_ts = latest_ts
    _metrics_id = metrics_id
    _worker_ingress_ts = worker_ingress_ts

  fun val apply(rerouter: Rerouter, producer: Producer ref) =>
    rerouter.reroute(producer, this)

  fun val route_with(router: (Router | DataRouter), producer: Producer ref) =>
    // !@ this doesn't correctly capture times for calculating latencies,
    // so what do we want to do about this?
    match (router, producer, _data)
    | (let data_router: DataRouter, let data_receiver: DataReceiver ref,
      let dm: DeliveryMsg)
    =>
      data_router.route(dm, _pipeline_time_spent, _producer_id,
        data_receiver, _seq_id, _latest_ts, _metrics_id,
        _worker_ingress_ts)
    else
      @printf[I32]("DataRouter failed to reroute message.\n".cstring())
      Fail()
    end

class val TypedDataReplayRoutingArguments[D: Any val] is RoutingArguments
  let _metric_name: String
  let _pipeline_time_spent: U64
  let _data: D
  let _producer_id: RoutingId
  let _seq_id: SeqId
  let _frac_ids: FractionalMessageId
  let _latest_ts: U64
  let _metrics_id: U16
  let _worker_ingress_ts: U64

  new val create(metric_name: String, pipeline_time_spent: U64, data: D,
    producer_id: RoutingId, seq_id: SeqId, frac_ids: FractionalMessageId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _metric_name = metric_name
    _pipeline_time_spent = pipeline_time_spent
    _data = data
    _producer_id = producer_id
    _seq_id = seq_id
    _frac_ids = frac_ids
    _latest_ts = latest_ts
    _metrics_id = metrics_id
    _worker_ingress_ts = worker_ingress_ts

  fun val apply(rerouter: Rerouter, producer: Producer ref) =>
    rerouter.reroute(producer, this)

  fun val route_with(router: (Router | DataRouter), producer: Producer ref) =>
    // !@ this doesn't correctly capture times for calculating latencies,
    // so what do we want to do about this?
    match (router, producer, _data)
    | (let data_router: DataRouter, let data_receiver: DataReceiver ref,
      let dm: ReplayableDeliveryMsg)
    =>
      data_router.replay_route(dm, _pipeline_time_spent, _producer_id,
        data_receiver, _seq_id, _latest_ts, _metrics_id,
        _worker_ingress_ts)
    else
      @printf[I32]("DataRouter failed to reroute message.\n".cstring())
      Fail()
    end
