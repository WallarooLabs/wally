/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "buffered"
use "net"
use "collections"
use "time"
use "wallaroo_labs/bytes"
use "wallaroo_labs/messages"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/topology"

class ExternalChannelListenNotifier is TCPListenNotify
  let _auth: AmbientAuth
  let _worker_name: String
  var _host: String = ""
  var _service: String = ""
  let _connections: Connections
  let _recovery_file_cleaner: RecoveryFileCleaner
  let _local_topology_initializer: LocalTopologyInitializer

  new iso create(name: String, auth: AmbientAuth, connections: Connections,
    recovery_file_cleaner: RecoveryFileCleaner,
    local_topology_initializer: LocalTopologyInitializer)
  =>
    _auth = auth
    _worker_name = name
    _connections = connections
    _recovery_file_cleaner = recovery_file_cleaner
    _local_topology_initializer = local_topology_initializer

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()?
      if _host == "::1" then _host = "127.0.0.1" end

      @printf[I32]("%s external: listening on %s:%s\n".cstring(),
        _worker_name.cstring(), _host.cstring(), _service.cstring())
    else
      @printf[I32]("%s external: couldn't get local address\n".cstring(),
        _worker_name.cstring())
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    @printf[I32]("%s external: couldn't listen\n".cstring(),
      _worker_name.cstring())
    listen.close()

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    ExternalChannelConnectNotifier(_worker_name, _auth, _connections,
      _recovery_file_cleaner, _local_topology_initializer)

  fun ref closed(listen: TCPListener ref) =>
    @printf[I32]("&s external: listener closed\n".cstring(),
      _worker_name.cstring())

class ExternalChannelConnectNotifier is TCPConnectionNotify
  let _auth: AmbientAuth
  let _worker_name: String
  let _connections: Connections
  let _recovery_file_cleaner: RecoveryFileCleaner
  let _local_topology_initializer: LocalTopologyInitializer
  var _header: Bool = true

  new iso create(name: String, auth: AmbientAuth, connections: Connections,
    recovery_file_cleaner: RecoveryFileCleaner,
    local_topology_initializer: LocalTopologyInitializer)
  =>
    _auth = auth
    _worker_name = name
    _connections = connections
    _recovery_file_cleaner = recovery_file_cleaner
    _local_topology_initializer = local_topology_initializer

  fun ref accepted(conn: TCPConnection ref) =>
    conn.expect(4)
    _connections.register_disposable(conn)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    n: USize): Bool
  =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()
        conn.expect(expect)
        _header = false
      else
        @printf[I32]("Error reading header on external channel\n".cstring())
      end
    else
      ifdef "trace" then
        @printf[I32]("Received msg on External Channel\n".cstring())
      end
      try
        let msg = ExternalMsgDecoder(consume data)?
        match msg
        | let m: ExternalPrintMsg =>
          ifdef "trace" then
            @printf[I32]("Received ExternalPrintMsg on External Channel\n"
              .cstring())
          end
          @printf[I32]("$$$ ExternalPrint: %s $$$\n".cstring(),
            m.message.cstring())
        | let m: ExternalRotateLogFilesMsg =>
          ifdef "trace" then
            @printf[I32](("Received ExternalRotateLogFilesMsg on External " +
              "Channel\n").cstring())
          end
          _connections.rotate_log_files(m.node_name)
        | let m: ExternalCleanShutdownMsg =>
          if m.msg != "" then
            @printf[I32]("External Clean Shutdown received: %s\n".cstring(),
              m.msg.cstring())
          else
            @printf[I32]("External Clean Shutdown received.\n".cstring())
          end
          try
            let clean_shutdown_msg = ChannelMsgEncoder.clean_shutdown(_auth)?
            _connections.send_control_to_cluster(clean_shutdown_msg)
            _recovery_file_cleaner.clean_recovery_files()
          else
            Fail()
          end
        | let m: ExternalShrinkMsg =>
          if m.query is true then
            _local_topology_initializer.shrinkable_query(conn)
          else
            _local_topology_initializer.initiate_shrink(m.node_names,
              m.num_nodes)
          end
        else
          @printf[I32](("Incoming External Message type not handled by " +
            "external channel.\n").cstring())
        end
      else
        @printf[I32]("Error decoding External Message on external channel.\n"
          .cstring())
      end

      conn.expect(4)
      _header = true
    end
    true

  fun ref connected(conn: TCPConnection ref) =>
    @printf[I32]("%s external channel is connected.\n".cstring(),
      _worker_name.cstring())

  fun ref connect_failed(conn: TCPConnection ref) =>
    @printf[I32]("%s external: connection failed!\n".cstring(),
      _worker_name.cstring())

  fun ref closed(conn: TCPConnection ref) =>
    @printf[I32]("ExternalChannelConnectNotifier: %s: server closed\n"
      .cstring(), _worker_name.cstring())
