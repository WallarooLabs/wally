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
use "net"
use "wallaroo_labs/guid"
use "wallaroo_labs/messages"
use "wallaroo"
use "wallaroo/core/network"
use "wallaroo/core/recovery"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/topology"

actor ClusterInitializer
  let _auth: AmbientAuth
  let _worker_name: String
  let _expected: USize
  let _connections: Connections
  let _distributor: Distributor
  let _layout_initializer: LayoutInitializer
  let _initializer_data_addr: Array[String] val
  let _metrics_conn: MetricsSink
  let _connections_ready_workers: Set[String] = Set[String]
  let _ready_workers: Set[String] = Set[String]
  var _control_identified: USize = 1
  var _data_receivers: USize = 1
  var _data_identified: USize = 0
  var _interconnected: USize = 1
  var _initialized: USize = 0
  var _topology_ready: Bool = false
  var _initializer_name: String

  let _worker_names: Array[String] = Array[String]
  let _control_addrs: Map[String, (String, String)] = _control_addrs.create()
  let _data_addrs: Map[String, (String, String)] = _data_addrs.create()

  new create(auth: AmbientAuth, worker_name: String, workers: USize,
    connections: Connections, distributor: Distributor,
    layout_initializer: LayoutInitializer,
    data_addr: Array[String] val, metrics_conn: MetricsSink,
    is_recovering: Bool, initializer_name: String)
  =>
    _auth = auth
    _worker_name = worker_name
    _expected = workers
    _connections = connections
    _initializer_data_addr = data_addr
    _metrics_conn = metrics_conn
    _distributor = distributor
    _layout_initializer = layout_initializer
    if is_recovering then _topology_ready = true end
    _initializer_name = initializer_name

  be start(initializer_name: String = "") =>
    // TODO: Pipeline initialization needs to be updated so that we
    // expect the initializer name to be added here.  There are going to
    // be multiple places it's added manually that need to be changed.
    if initializer_name != "" then
      _initializer_name = initializer_name
      _worker_names.push(_initializer_name)
    end
    if _expected == 1 then
      // This is a single worker cluster. We are ready to proceed with
      // initialization.
      _topology_ready = true
      _distributor.distribute(this, _expected, recover Array[String] end,
        _initializer_name)
      _connections.save_connections()
      _layout_initializer.create_data_channel_listener(
        recover Array[String] end, "", "", this)
    end

  be identify_control_address(worker: String, host: String, service: String) =>
    if (not _control_addrs.contains(worker)) and (not _topology_ready) then
      @printf[I32]("Worker %s control channel identified\n".cstring(),
        worker.cstring())
      _worker_names.push(worker)
      _control_addrs(worker) = (host, service)
      _control_identified = _control_identified + 1
      if _control_identified == _expected then
        @printf[I32]("All worker control channels identified\n".cstring())

        _create_data_channel_listeners()
      end
    end

  be identify_data_address(worker: String, host: String, service: String) =>
    if (not _data_addrs.contains(worker)) and (not _topology_ready) then
      @printf[I32]("Worker %s data channel identified\n".cstring(),
        worker.cstring())
      _data_addrs(worker) = (host, service)
      _data_identified = _data_identified + 1
      if _data_identified == _expected then
        @printf[I32]("All worker data channels identified\n".cstring())

        _create_interconnections()
      end
    end

  be distribute_local_topologies(ts: Map[String, LocalTopology] val) =>
    if _worker_names.size() != ts.size() then
      @printf[I32]("We need one local topology for each worker\n".cstring())
    else
      @printf[I32]("Distributing local topologies to workers\n".cstring())
      for (worker, topology) in ts.pairs() do
        try
          let spin_up_msg = ChannelMsgEncoder.spin_up_local_topology(
            topology, _auth)?
          _connections.send_control(worker, spin_up_msg)
        end
      end
      @printf[I32]("Finished distributing\n".cstring())
    end

 be connections_ready(worker_name: String) =>
    if not _connections_ready_workers.contains(worker_name) then
      _connections_ready_workers.set(worker_name)
      _interconnected = _interconnected + 1
      if _interconnected == _expected then
        let names = recover trn Array[String] end
        for name in _worker_names.values() do
          names.push(name)
        end

        _distributor.distribute(this, _expected, consume names,
          _initializer_name)
      end
    end

  be topology_ready(worker_name: String) =>
    if not _ready_workers.contains(worker_name) then
      @printf[I32]("%s reported topology ready!\n".cstring(),
        worker_name.cstring())
      _ready_workers.set(worker_name)
      _initialized = _initialized + 1
      if _initialized == _expected then
        @printf[I32]("All %llu workers reporting Topology ready!\n".cstring(),
          _expected)
        _distributor.topology_ready()

        _topology_ready = true
      end
    else
      @printf[I32]("Duplicate topology ready sent to worker initializer!\n"
        .cstring())
    end

  fun _create_data_channel_listeners() =>
    let ws = recover trn Array[String] end

    if not _worker_names.contains(_initializer_name) then
      ws.push(_initializer_name)
    end
    for w in _worker_names.values() do
      ws.push(w)
    end

    let workers: Array[String] val = consume ws

    try
      let create_data_channel_listener_msg =
        ChannelMsgEncoder.create_data_channel_listener(workers, _auth)?
      for key in _control_addrs.keys() do
        _connections.send_control(key, create_data_channel_listener_msg)
      end

      // Pass in empty host and service because data listener is created
      // in a special manner in .create_data_receiver() for initializer
      _layout_initializer.create_data_channel_listener(workers, "", "",
        this)
    else
      @printf[I32]("Failed to create message to create data receivers\n"
        .cstring())
    end

  fun _create_interconnections() =>
    (let c_addrs, let d_addrs) = _generate_addresses_map()
    try
      let message = ChannelMsgEncoder.create_connections(c_addrs, d_addrs,
        _auth)?
      for key in _control_addrs.keys() do
        _connections.send_control(key, message)
      end

      _connections.save_connections()
      _connections.update_boundaries(_layout_initializer)
    else
      @printf[I32]("Initializer: Error initializing interconnections\n"
        .cstring())
    end

  fun _generate_addresses_map(): (Map[String, (String, String)] val,
    Map[String, (String, String)] val)
  =>
    let map = recover trn Map[String, Map[String, (String, String)]] end
    let control_map = recover trn Map[String, (String, String)] end
    for (key, value) in _control_addrs.pairs() do
      control_map(key) = value
    end
    let data_map = recover trn Map[String, (String, String)] end
    for (key, value) in _data_addrs.pairs() do
      data_map(key) = value
    end

    (consume control_map, consume data_map)
