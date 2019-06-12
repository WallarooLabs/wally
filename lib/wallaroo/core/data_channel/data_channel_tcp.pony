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

use "buffered"
use "collections"
use "time"
use "files"
use "wallaroo/core/autoscale"
use "wallaroo/core/barrier"
use "wallaroo/core/boundary"
use "wallaroo/core/checkpoint"
use "wallaroo/core/common"
use "wallaroo/core/data_receiver"
use "wallaroo/core/initialization"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/network"
use "wallaroo/core/recovery"
use "wallaroo/core/registries"
use "wallaroo/core/tcp_actor"
use "wallaroo/core/topology"
use "wallaroo_labs/bytes"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"


class DataChannelListenNotifier is DataChannelListenNotify
  let _name: String
  let _auth: AmbientAuth
  let _is_initializer: Bool
  let _recovery_file: FilePath
  var _host: String = ""
  var _service: String = ""
  let _connections: Connections
  let _metrics_reporter: MetricsReporter
  let _layout_initializer: LayoutInitializer tag
  let _data_receivers: DataReceivers
  let _recovery_replayer: RecoveryReconnecter
  let _autoscale: Autoscale
  let _router_registry: RouterRegistry
  let _the_journal: SimpleJournal
  let _do_local_file_io: Bool
  let _joining_existing_cluster: Bool

  new iso create(name: String, auth: AmbientAuth,
    connections: Connections, is_initializer: Bool,
    metrics_reporter: MetricsReporter iso,
    recovery_file: FilePath,
    layout_initializer: LayoutInitializer tag,
    data_receivers: DataReceivers, recovery_replayer: RecoveryReconnecter,
    autoscale: Autoscale,
    router_registry: RouterRegistry, the_journal: SimpleJournal,
    do_local_file_io: Bool, joining: Bool = false)
  =>
    _name = name
    _auth = auth
    _is_initializer = is_initializer
    _connections = connections
    _metrics_reporter = consume metrics_reporter
    _recovery_file = recovery_file
    _layout_initializer = layout_initializer
    _data_receivers = data_receivers
    _recovery_replayer = recovery_replayer
    _autoscale = autoscale
    _router_registry = router_registry
    _the_journal = the_journal
    _do_local_file_io = do_local_file_io
    _joining_existing_cluster = joining

  fun ref listening(listen: DataChannelListener ref) =>
    try
      (_host, _service) = listen.local_address().name()?
      if _host == "::1" then _host = "127.0.0.1" end

      if not _is_initializer then
        _connections.register_my_data_addr(_host, _service)
      end
      _router_registry.register_data_channel_listener(listen)

      @printf[I32]((_name + " data channel: listening on " + _host + ":" +
        _service + "\n").cstring())
      if _recovery_file.exists() then
        @printf[I32]("Recovery file exists for data channel\n".cstring())
      end
      if _joining_existing_cluster then
        //TODO: Do we actually need to do this? Isn't this sent as
        // part of joining worker initialized message?
        let message = ChannelMsgEncoder.identify_data_port(_name, _service,
          _auth)?
        _connections.send_control_to_cluster(message)
      else
        if not _recovery_file.exists() then
          let message = ChannelMsgEncoder.identify_data_port(_name, _service,
            _auth)?
          _connections.send_control_to_cluster(message)
        end
      end
      let f = AsyncJournalledFile(_recovery_file, _the_journal, _auth, _do_local_file_io)
      f.print(_host)
      f.print(_service)
      f.sync()
      f.dispose()
      // TODO: AsyncJournalledFile does not provide implicit sync semantics here
    else
      @printf[I32]((_name + " data: couldn't get local address\n").cstring())
      listen.close()
    end

  fun ref not_listening(listen: DataChannelListener ref) =>
    (let h, let s) = try
      listen.local_address().name(None, false)?
    else
      listen.requested_address()
    end
    @printf[I32]((_name + " data: unable to listen on (%s:%s)\n").cstring(),
      h.cstring(), s.cstring())
    Fail()

  fun ref connected(listener: DataChannelListener ref,
    router_registry: RouterRegistry,
    ns: U32, init_size: USize, max_size: USize): DataChannel
  =>
    let tcp_handler_builder = DataChannelTCPHandlerBuilder(ns,
      init_size, max_size)
    DataChannel._accept(listener, tcp_handler_builder, _connections, _auth,
      _metrics_reporter.clone(), _layout_initializer, _data_receivers,
      _recovery_replayer, _autoscale, router_registry)
