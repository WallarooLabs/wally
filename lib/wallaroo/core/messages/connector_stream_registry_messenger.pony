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

use "collections"
use "wallaroo_labs/mort"
use "wallaroo/core/common"
use "wallaroo/core/network"
use "wallaroo/core/source/connector_source"

primitive ConnectorStreamRegistryMessenger

  fun stream_notify(leader: WorkerName, worker_name: WorkerName,
    source_name: String, stream: StreamTuple,
    request_id: ConnectorStreamNotifyId, connections: Connections,
    auth: AmbientAuth)
  =>
    try
      let stream_notify_msg = ChannelMsgEncoder.connector_stream_notify(
        worker_name, source_name, stream, request_id, auth)?
      connections.send_control(leader, stream_notify_msg)
    else
      Fail()
    end

  fun respond_to_stream_notify(worker_name: WorkerName,
    source_name: String, success: Bool, stream: StreamTuple,
    request_id: ConnectorStreamNotifyId, connections: Connections,
    auth: AmbientAuth)
  =>
    try
      let stream_notify_response_msg =
        ChannelMsgEncoder.connector_stream_notify_response(
          source_name, success, stream, request_id, auth)?
        connections.send_control(worker_name, stream_notify_response_msg)
    else
      Fail()
    end

  fun streams_relinquish(leader: WorkerName,
    worker_name: WorkerName, source_name: String,
    streams: Array[StreamTuple] val, connections: Connections,
    auth: AmbientAuth)
    =>
      try
        let streams_relinquish_msg =
          ChannelMsgEncoder.connector_streams_relinquish(worker_name,
            source_name, streams, auth)?
          connections.send_control(leader, streams_relinquish_msg)
      else
        Fail()
      end

  fun add_source_addr(leader: WorkerName,
    worker_name: WorkerName, source_name: String, host: String,
    service: String, connections: Connections, auth: AmbientAuth)
  =>
    try
      let connector_add_source_addr_msg =
        ChannelMsgEncoder.connector_add_source_addr(worker_name,
          source_name, host, service, auth)?
      connections.send_control(leader, connector_add_source_addr_msg)

    else
      Fail()
    end

  fun leader_state_received_ack(leader_name: WorkerName,
    worker_name: WorkerName, source_name: String, connections: Connections,
    auth: AmbientAuth)
  =>
    try
      let connector_new_leader_ack_msg =
        ChannelMsgEncoder.connector_leader_state_received_ack(leader_name,
          source_name, auth)?
        connections.send_control(worker_name, connector_new_leader_ack_msg)
    else
      Fail()
    end

  fun broadcast_new_leader(leader_name: WorkerName,
    source_name: String, workers_list: Array[WorkerName] val,
    connections: Connections, auth: AmbientAuth)
  =>
    try
      let connector_new_leader_msg =
        ChannelMsgEncoder.connector_new_leader(leader_name,
          source_name, auth)?
        for worker in workers_list.values() do
          connections.send_control(worker, connector_new_leader_msg)
        end
    else
      Fail()
    end

  fun leadership_relinquish_state(new_leader_name: WorkerName,
    relinquishing_leader_name: WorkerName, source_name: String,
    active_stream_map: Map[StreamId, WorkerName] val,
    inactive_stream_map: Map[StreamId, StreamTuple] val,
    source_addr_map: Map[WorkerName, (String, String)] val,
    connections: Connections, auth: AmbientAuth)
  =>
    try
      let connector_leadership_relinquish_state_msg =
        ChannelMsgEncoder.connector_leadership_relinquish_state(
          relinquishing_leader_name, source_name, active_stream_map,
          inactive_stream_map, source_addr_map, auth)?
      connections.send_control(new_leader_name,
        connector_leadership_relinquish_state_msg)
    else
      Fail()
    end

  fun leader_name_request(requesting_worker_name: WorkerName,
    receiving_worker_name: WorkerName, source_name: String,
    connections: Connections, auth: AmbientAuth)
  =>
    try
      let connector_leader_name_request_msg =
        ChannelMsgEncoder.connector_leader_name_request(requesting_worker_name,
          source_name, auth)?
      connections.send_control(receiving_worker_name, connector_leader_name_request_msg)
    else
      Fail()
    end

  fun leader_name_response(worker_name: WorkerName,
    leader_name: WorkerName, source_name: String, connections: Connections,
    auth: AmbientAuth)
  =>
    try
      let connector_leader_name_response_msg =
        ChannelMsgEncoder.connector_leader_name_response(leader_name,
          source_name, auth)?
      connections.send_control(worker_name, connector_leader_name_response_msg)
    else
      Fail()
    end

  fun streams_shrink(leader_name: WorkerName,
    worker_name: WorkerName, source_name: String,
    streams: Array[StreamTuple] val, source_id: RoutingId,
    connections: Connections, auth: AmbientAuth)
  =>
    try
      let connector_streams_shrink_msg =
        ChannelMsgEncoder.connector_streams_shrink(worker_name,
          source_name, streams, source_id, auth)?
      connections.send_control(leader_name, connector_streams_shrink_msg)
    else
      Fail()
    end

  fun respond_to_streams_shrink(worker_name: WorkerName,
    source_name: String, streams: Array[StreamTuple] val, host: String,
    service: String, source_id: RoutingId, connections: Connections,
    auth: AmbientAuth)
  =>
    try
      let connector_streams_shrink_response_msg =
        ChannelMsgEncoder.connector_streams_shrink_response(source_name,
          streams, host, service, source_id, auth)?
      connections.send_control(worker_name,
        connector_streams_shrink_response_msg)
    else
      Fail()
    end

  fun worker_shrink_complete(source_name: String,
    leader_name: WorkerName, worker_name: WorkerName,
    connections: Connections, auth: AmbientAuth)
  =>
    try
      let connector_worker_shrink_complete_msg =
        ChannelMsgEncoder.connector_worker_shrink_complete(source_name,
          worker_name, auth)?
      connections.send_control(leader_name,
        connector_worker_shrink_complete_msg)
    else
      Fail()
    end
