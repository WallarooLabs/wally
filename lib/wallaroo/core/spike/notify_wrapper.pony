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

use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/network"

primitive SpikeBoundaryNotifyWrapper
  fun apply(notify: BoundaryNotify iso,
    config: SpikeConfig val): TestableBoundaryNotify[OutgoingBoundary ref] iso^
  =>
    if config.drop then
      recover BoundaryDropConnection(consume notify, config) end
    else
      consume notify
    end

class BoundaryDropConnection is TestableBoundaryNotify[OutgoingBoundary ref]
  let _notify: BoundaryNotify
  let _drop_connection: DropConnection[OutgoingBoundary ref]

  new create(notify: BoundaryNotify ref, config: SpikeConfig val) =>
    _notify = notify
    _drop_connection = DropConnection[OutgoingBoundary ref](config, notify)

  fun ref update_address(host: String, service: String) =>
    _notify.update_address(host, service)

  fun ref register_routing_id(r_id: RoutingId) =>
    _notify.register_routing_id(r_id)

  //////////////////////////////
  // GeneralTCPSource interface
  //////////////////////////////
  fun ref connecting(conn: OutgoingBoundary ref, count: U32) =>
    _drop_connection.connecting(conn, count)

  fun ref connected(conn: OutgoingBoundary ref) =>
    _drop_connection.connected(conn)

  fun ref connect_failed(conn: OutgoingBoundary ref) =>
    _drop_connection.connect_failed(conn)

  fun ref closed(conn: OutgoingBoundary ref, locally_initiated_close: Bool) =>
    _drop_connection.closed(conn, locally_initiated_close)

  fun ref sentv(conn: OutgoingBoundary ref,
    data: ByteSeqIter): ByteSeqIter
  =>
    _drop_connection.sentv(conn, data)

  fun ref received(conn: OutgoingBoundary ref, data: Array[U8] iso,
    times: USize): Bool
  =>
    _drop_connection.received(conn, consume data, times)

  fun ref expect(conn: OutgoingBoundary ref, qty: USize): USize =>
    _drop_connection.expect(conn, qty)

  fun ref throttled(conn: OutgoingBoundary ref) =>
    _drop_connection.throttled(conn)

  fun ref unthrottled(conn: OutgoingBoundary ref) =>
    _drop_connection.unthrottled(conn)

  fun ref dispose() =>
    _drop_connection.dispose()

