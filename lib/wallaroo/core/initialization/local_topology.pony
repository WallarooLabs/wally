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
use "files"
use "net"
use "promises"
use "serialise"
use "wallaroo"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/keys"
use "wallaroo/ent/barrier"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/cluster_manager"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/checkpoint"
use "wallaroo/core/data_channel"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/barrier_source"
use "wallaroo/core/topology"
use "wallaroo_labs/collection_helpers"
use "wallaroo_labs/dag"
use "wallaroo_labs/equality"
use "wallaroo_labs/messages"
use "wallaroo_labs/mort"
use "wallaroo_labs/queue"


class val LocalTopology
  let _app_name: String
  let _worker_name: WorkerName
  let _graph: Dag[StepInitializer] val
  // A map from node ids in the graph to one or more routing ids per node,
  // depending on the parallelism.
  let _routing_ids: Map[U128, SetIs[RoutingId] val] val
  let state_routing_ids: Map[StateName, Map[WorkerName, RoutingId] val] val
  let stateless_partition_routing_ids:
    Map[RoutingId, Map[WorkerName, RoutingId] val] val
  let worker_names: Array[WorkerName] val
  // Workers that cannot be removed during shrink to fit
  let non_shrinkable: SetIs[WorkerName] val
  // Each worker has one BarrierSource with a unique id
  let barrier_source_id: RoutingId

  new val create(name': String, worker_name': WorkerName,
    graph': Dag[StepInitializer] val,
    routing_ids': Map[U128, SetIs[RoutingId] val] val,
    worker_names': Array[WorkerName] val,
    non_shrinkable': SetIs[WorkerName] val,
    state_routing_ids': Map[StateName, Map[WorkerName, RoutingId] val] val,
    stateless_partition_routing_ids':
      Map[RoutingId, Map[WorkerName, RoutingId] val] val,
    barrier_source_id': RoutingId)
  =>
    _app_name = name'
    _worker_name = worker_name'
    _graph = graph'
    _routing_ids = routing_ids'
    worker_names = worker_names'
    non_shrinkable = non_shrinkable'
    state_routing_ids = state_routing_ids'
    stateless_partition_routing_ids = stateless_partition_routing_ids'
    barrier_source_id = barrier_source_id'

  fun routing_ids(): Map[U128, SetIs[RoutingId] val] val =>
    _routing_ids

  fun graph(): Dag[StepInitializer] val =>
    _graph

  fun name(): String =>
    _app_name

  fun worker_name(): WorkerName =>
    _worker_name

  fun is_empty(): Bool =>
    _graph.is_empty()

  fun val assign_routing_ids(gen: RoutingIdGenerator): LocalTopology =>
    let r_ids = recover iso Map[U128, SetIs[RoutingId] val] end
    for n in _graph.nodes() do
      let next = recover iso SetIs[RoutingId] end
      for _ in Range(0, n.value.parallelism()) do
        next.set(gen())
      end
      r_ids(n.id) = consume next
    end
    LocalTopology(_app_name, _worker_name, _graph, consume r_ids,
      worker_names, non_shrinkable,
      state_routing_ids, stateless_partition_routing_ids, barrier_source_id)

  fun val state_routing_ids_for(w: WorkerName): Map[StateName, RoutingId] val
  =>
    let sri = recover iso Map[StateName, RoutingId] end
    for (s_name, ws) in state_routing_ids.pairs() do
      try
        sri(s_name) = ws(w)?
      else
        Fail()
      end
    end
    consume sri

  fun val stateless_partition_routing_ids_for(w: WorkerName):
    Map[RoutingId, RoutingId] val
  =>
    let spri = recover iso Map[RoutingId, RoutingId] end
    for (group_id, ws) in stateless_partition_routing_ids.pairs() do
      try
        spri(group_id) = ws(w)?
      else
        Fail()
      end
    end
    consume spri

  fun val add_new_worker(new_worker: WorkerName,
    joining_state_routing_ids: (Map[StateName, RoutingId] val | None) = None,
    joining_stateless_routing_ids: (Map[RoutingId, RoutingId] val | None)
      = None): LocalTopology
  =>
    try
      let routing_id_gen = RoutingIdGenerator
      // Get or generate state routing ids for new worker
      let new_state_routing_ids_iso =
        recover iso Map[StateName, Map[WorkerName, RoutingId] val] end
      for (state_name, ws_map) in state_routing_ids.pairs() do
        let new_ws_map = recover iso Map[WorkerName, RoutingId] end
        for (w, r_id) in ws_map.pairs() do
          new_ws_map(w) = r_id
        end
        match joining_state_routing_ids
        | let jsri: Map[StateName, RoutingId] val =>
          new_ws_map(new_worker) = jsri(state_name)?
        else
          new_ws_map(new_worker) = routing_id_gen()
        end
        new_state_routing_ids_iso(state_name) = consume new_ws_map
      end
      let new_state_routing_ids = consume val new_state_routing_ids_iso

      // Get or generate stateless partition routing ids for new worker
      let new_stateless_routing_ids_iso =
        recover iso Map[RoutingId, Map[WorkerName, RoutingId] val] end
      for (group_id, ws_map) in stateless_partition_routing_ids.pairs() do
        let new_ws_map = recover iso Map[WorkerName, RoutingId] end
        for (w, r_id) in ws_map.pairs() do
          new_ws_map(w) = r_id
        end
        match joining_stateless_routing_ids
        | let jsri: Map[RoutingId, RoutingId] val =>
          new_ws_map(new_worker) = jsri(group_id)?
        else
          new_ws_map(new_worker) = routing_id_gen()
        end
        new_stateless_routing_ids_iso(group_id) = consume new_ws_map
      end
      let new_stateless_routing_ids = consume val new_stateless_routing_ids_iso

      let new_worker_names = recover iso Array[WorkerName] end
      for w in worker_names.values() do
        new_worker_names.push(w)
      end
      new_worker_names.push(new_worker)

      LocalTopology(_app_name, new_worker, _graph, _routing_ids,
        consume new_worker_names, non_shrinkable, new_state_routing_ids,
        new_stateless_routing_ids, barrier_source_id)
    else
      Fail()
      this
    end

  fun val remove_worker(ws: Array[WorkerName] val): LocalTopology
  =>
    let new_worker_names = recover iso Array[WorkerName] end
    for w in worker_names.values() do
      if not ArrayHelpers[WorkerName].contains[WorkerName](ws, w) then
        new_worker_names.push(w)
      end
    end

    // Remove state routing ids
    let new_state_routing_ids =
      recover iso Map[StateName, Map[WorkerName, RoutingId] val] end
    for (state_name, ws_map) in state_routing_ids.pairs() do
      let new_ws_map = recover iso Map[WorkerName, RoutingId] end
      for (w, r_id) in ws_map.pairs() do
        if not ArrayHelpers[WorkerName].contains[WorkerName](ws, w) then
          new_ws_map(w) = r_id
        end
      end
      new_state_routing_ids(state_name) = consume new_ws_map
    end

    // Remove stateless partition routing ids
    let new_stateless_partition_routing_ids =
      recover iso Map[RoutingId, Map[WorkerName, RoutingId] val] end
    for (group_id, ws_map) in stateless_partition_routing_ids.pairs() do
      let new_ws_map = recover iso Map[WorkerName, RoutingId] end
      for (w, r_id) in ws_map.pairs() do
        if not ArrayHelpers[WorkerName].contains[WorkerName](ws, w) then
          new_ws_map(w) = r_id
        end
      end
      new_stateless_partition_routing_ids(group_id) = consume new_ws_map
    end

    LocalTopology(_app_name, _worker_name, _graph, _routing_ids,
      consume new_worker_names, non_shrinkable, consume new_state_routing_ids,
      consume new_stateless_partition_routing_ids, barrier_source_id)

  fun eq(that: box->LocalTopology): Bool =>
    // This assumes that _graph and _pre_state_data never change over time
    (_app_name == that._app_name) and
      (_worker_name == that._worker_name) and
      (_graph is that._graph) and
      //!@
      // MapEquality2[U128, ProxyAddress, U128](_step_map, that._step_map)
      //   and
      // MapEquality[String, StateSubpartitions](_state_builders,
      //   that._state_builders) and
      // (_pre_state_data is that._pre_state_data) and
      // MapEquality[String, U128](_boundary_ids, that._boundary_ids) and
      ArrayEquality[String](worker_names, that.worker_names)

  fun ne(that: box->LocalTopology): Bool => not eq(that)

actor LocalTopologyInitializer is LayoutInitializer
  let _app_name: String
  let _worker_name: WorkerName
  let _env: Env
  let _auth: AmbientAuth
  let _connections: Connections
  let _router_registry: RouterRegistry
  let _metrics_conn: MetricsSink
  let _data_receivers: DataReceivers
  let _event_log: EventLog
  let _recovery: Recovery
  let _recovery_replayer: RecoveryReconnecter
  let _checkpoint_initiator: CheckpointInitiator
  let _barrier_initiator: BarrierInitiator
  var _is_initializer: Bool
  var _outgoing_boundary_builders:
    Map[WorkerName, OutgoingBoundaryBuilder] val =
      recover Map[WorkerName, OutgoingBoundaryBuilder] end
  var _outgoing_boundaries: Map[WorkerName, OutgoingBoundary] val =
    recover Map[WorkerName, OutgoingBoundary] end
  var _topology: (LocalTopology | None) = None
  let _local_topology_file: String
  var _cluster_initializer: (ClusterInitializer | None) = None
  let _data_channel_file: String
  let _worker_names_file: String
  let _local_keys_file: LocalKeysFile
  let _the_journal: SimpleJournal
  let _do_local_file_io: Bool
  var _topology_initialized: Bool = false
  var _recovered_worker_names: Array[WorkerName] val =
    recover val Array[WorkerName] end
  var _recovering: Bool = false
  let _is_joining: Bool

  let _routing_id_gen: RoutingIdGenerator = RoutingIdGenerator

  // Lifecycle
  var _created: SetIs[Initializable] = _created.create()
  var _initialized: SetIs[Initializable] = _initialized.create()
  var _ready_to_work: SetIs[Initializable] = _ready_to_work.create()
  let _initializables: Initializables = Initializables
  var _event_log_ready_to_work: Bool = false
  var _recovery_ready_to_work: Bool = false
  var _initialization_lifecycle_complete: Bool = false

  // Accumulate all SourceListenerBuilders so we can build them
  // once EventLog signals we're ready
  let sl_builders: Array[SourceListenerBuilder] =
    recover iso Array[SourceListenerBuilder] end

  // Cluster Management
  var _cluster_manager: (ClusterManager | None) = None

  var _t: USize = 0

  new create(app_name: String, worker_name: WorkerName, env: Env,
    auth: AmbientAuth, connections: Connections,
    router_registry: RouterRegistry, metrics_conn: MetricsSink,
    is_initializer: Bool, data_receivers: DataReceivers,
    event_log: EventLog, recovery: Recovery,
    recovery_replayer: RecoveryReconnecter,
    checkpoint_initiator: CheckpointInitiator, barrier_initiator: BarrierInitiator,
    local_topology_file: String, data_channel_file: String,
    worker_names_file: String, local_keys_filepath: FilePath,
    the_journal: SimpleJournal, do_local_file_io: Bool,
    cluster_manager: (ClusterManager | None) = None,
    is_joining: Bool = false)
  =>
    _app_name = app_name
    _worker_name = worker_name
    _env = env
    _auth = auth
    _connections = connections
    _router_registry = router_registry
    _metrics_conn = metrics_conn
    _is_initializer = is_initializer
    _data_receivers = data_receivers
    _event_log = event_log
    _recovery = recovery
    _recovery_replayer = recovery_replayer
    _checkpoint_initiator = checkpoint_initiator
    _barrier_initiator = barrier_initiator
    _local_topology_file = local_topology_file
    _data_channel_file = data_channel_file
    _worker_names_file = worker_names_file
    _local_keys_file = LocalKeysFile(local_keys_filepath, the_journal, auth,
      do_local_file_io)
    _the_journal = the_journal
    _do_local_file_io = do_local_file_io
    _cluster_manager = cluster_manager
    _is_joining = is_joining
    _router_registry.register_local_topology_initializer(this)
    _initializables.set(_checkpoint_initiator)
    _initializables.set(_barrier_initiator)
    _recovery.update_initializer(this)

  be update_topology(t: LocalTopology) =>
    _topology = t

  be update_boundaries(bs: Map[WorkerName, OutgoingBoundary] val,
    bbs: Map[WorkerName, OutgoingBoundaryBuilder] val)
  =>
    // This should only be called during initialization
    if (_outgoing_boundaries.size() > 0) or
       (_outgoing_boundary_builders.size() > 0)
    then
      Fail()
    end

    _outgoing_boundaries = bs
    _outgoing_boundary_builders = bbs
    // TODO: This no longer captures all boundaries because of boundary per
    // source. Does this matter without backpressure?
    for boundary in bs.values() do
      _initializables.set(boundary)
    end

  be create_data_channel_listener(ws: Array[WorkerName] val,
    host: String, service: String,
    cluster_initializer: (ClusterInitializer | None) = None)
  =>
    try
      let data_channel_filepath = FilePath(_auth, _data_channel_file)?
      if not _is_initializer then
        let data_notifier: DataChannelListenNotify iso =
          DataChannelListenNotifier(_worker_name, _auth, _connections,
            _is_initializer,
            MetricsReporter(_app_name, _worker_name,
              _metrics_conn),
            data_channel_filepath, this, _data_receivers, _recovery_replayer,
            _router_registry, _the_journal, _do_local_file_io)

        _connections.make_and_register_recoverable_data_channel_listener(
          _auth, consume data_notifier, _router_registry,
          data_channel_filepath, host, service)
      else
        match cluster_initializer
          | let ci: ClusterInitializer =>
            _connections.create_initializer_data_channel_listener(
              _data_receivers, _recovery_replayer, _router_registry, ci,
              data_channel_filepath, this)
        end
      end
    else
      @printf[I32]("FAIL: cannot create data channel\n".cstring())
    end

  be create_connections(control_addrs: Map[WorkerName, (String, String)] val,
    data_addrs: Map[WorkerName, (String, String)] val)
  =>
    _connections.create_connections(control_addrs, data_addrs, this,
      _router_registry)

  be initialize(cluster_initializer: (ClusterInitializer | None) = None,
    checkpoint_target: (CheckpointId | None) = None,
    recovering_without_resilience: Bool = false)
  =>
    _recovering =
      match checkpoint_target
      | let id: CheckpointId =>
        _recovery.update_checkpoint_id(id)
        true
      else
        false
      end

    if _topology_initialized then
      ifdef debug then
        // Currently, recovery in a single worker cluster is a special case.
        // We do not need to recover connections to other workers, so we
        // initialize immediately in Startup. However, we eventually trigger
        // code in connections.pony where initialize() is called again. For
        // now, this code simply returns in that scenario to avoid double
        // initialization.
        Invariant(
          try (_topology as LocalTopology).worker_names.size() == 1
          else false end
        )
      end
      return
    end

    @printf[I32](("------------------------------------------------------" +
      "---\n").cstring())
    @printf[I32]("|v|v|v|Initializing Local Topology|v|v|v|\n\n".cstring())
    _cluster_initializer = cluster_initializer

    try
      // Check if we are recovering and need to read our local topology in
      // from disk.
      try
        let local_topology_file = FilePath(_auth, _local_topology_file)?
        if local_topology_file.exists() then
          //we are recovering an existing worker topology
          let data = recover val
            // TODO: We assume that all journal data is copied to local file
            // system first
            let file = File(local_topology_file)
            file.read(file.size())
          end
          match Serialised.input(InputSerialisedAuth(_auth), data)(
            DeserialiseAuth(_auth))?
          | let t: LocalTopology val =>
            _topology = t
          else
            @printf[I32]("Error restoring previous topology!".cstring())
            Fail()
          end
        end
      else
        @printf[I32]("Error restoring previous topology!".cstring())
        Fail()
      end

      match _topology
      | let t: LocalTopology =>
        let worker_count = t.worker_names.size()

        if (worker_count > 1) and (_outgoing_boundaries.size() == 0) then
          @printf[I32]("Outgoing boundaries not set up!\n".cstring())
          error
        end

        for w in t.worker_names.values() do
          _barrier_initiator.add_worker(w)
          _checkpoint_initiator.add_worker(w)
        end

        _save_local_topology()
        _save_worker_names()

        // Determine if we need to read in local keys for our state collections
        let local_keys: Map[StateName, SetIs[Key] val] val =
          if _recovering then
            @printf[I32]("Reading local keys from file.\n".cstring())
            try
              _local_keys_file.read_local_keys(
                checkpoint_target as CheckpointId)
            else
              Fail()
              recover val Map[StateName, SetIs[Key] val] end
            end
          else
            // We don't have any local keys yet since this is our initial
            // startup.
            recover iso Map[StateName, SetIs[Key] val] end
          end

        if t.is_empty() then
          @printf[I32]("----This worker has no steps----\n".cstring())
        end

        let graph = t.graph()

        @printf[I32]("Creating graph:\n".cstring())
        @printf[I32]((graph.string() + "\n").cstring())

        @printf[I32]("\nInitializing %s application locally:\n\n".cstring(),
          t.name().cstring())

        // Keep track of all Consumers by id so we can create a
        // DataRouter for the data channel boundary
        var data_routes = recover trn Map[U128, Consumer] end

        // Keep track of routers to the steps we've built
        let built_routers = Map[U128, Router]

        // Keep track of state and stateless steps for registration with
        // DataRouters.
        let built_state_steps = Map[StateName, Array[Step] val]
        let built_stateless_steps = Map[RoutingId, Array[Step] val]

        // Keep track of partition routers
        let state_partition_routers = Map[StateName, StatePartitionRouter]
        let stateless_partition_routers =
          Map[RoutingId, StatelessPartitionRouter]

        // If this worker has at least one Source, then we'll also need a
        // a BarrierSource to ensure that checkpoint barriers always get to
        // source targets (even if our local Sources pop out of existence
        // for some reason, as when TCPSources disconnect).
        var barrier_source: (BarrierSource | None) = None

        /////////
        // Initialize based on DAG
        //
        // ASSUMPTION: Acyclic graph
        /////////
        let nodes_to_initialize = Array[DagNode[StepInitializer] val]

        //////////////////////////////////////////////////////////////////////
        // 1. Find graph sinks and add to nodes to initialize queue.
        //    We'll work our way backwards.
        //    We use a frontier queue to ensure that we add to the
        //    initialization queue in waves, starting with all sinks, followed
        //    by all inputs to those sinks, followed by all inputs to those
        //    inputs, etc. until we get to the sources.
        let frontier = Array[DagNode[StepInitializer] val]

        @printf[I32]("Adding sink nodes to nodes to initialize\n".cstring())
        for sink_node in graph.sinks() do
          @printf[I32](("Adding %s node to nodes to initialize\n").cstring(),
            sink_node.value.name().cstring())
          nodes_to_initialize.push(sink_node)
          frontier.push(sink_node)
        end

        while frontier.size() > 0 do
          let next_node = frontier.shift()?
          for i_node in next_node.ins() do
            if not nodes_to_initialize.contains(i_node) then
              let should_add =
                match i_node.value
                // Currently only the initializer handles sources
                | let sd: SourceData => _is_initializer
                else true end
              if should_add then
                @printf[I32](("Adding %s node to nodes to initialize\n")
                  .cstring(), i_node.value.name().cstring())
                nodes_to_initialize.push(i_node)
                frontier.push(i_node)
              end
            end
          end
        end

        //////////////////////////////////////////////////////////////////////
        // 2. Loop: Get next node from nodes to initialize queue, and check if
        //          all its outputs have been created yet.
        //       if no, send to that node to end of nodes to initialize queue.
        //       if yes, build the actor (connecting it to its output actors, //         which have already been built)
        // If there are no cycles (as per our assumption), this will terminate
        while nodes_to_initialize.size() > 0 do
          let next_node =
            try
              nodes_to_initialize.shift()?
            else
              @printf[I32](("Graph nodes to initialize queue was empty when " +
                "node was still expected\n").cstring())
              error
            end

          @printf[I32]("!@ next_node.id %s\n".cstring(), next_node.id.string().cstring())

          if built_routers.contains(next_node.id) then
            @printf[I32](("We've already handled %s with id %s\n").cstring(),
              next_node.value.name().cstring(),
              next_node.id.string().cstring())
            Fail()
          end

          // We are only ready to build a node if all of its outputs
          // have been built
          if _is_ready_for_building(next_node, built_routers) then
            @printf[I32](("Initializing " + next_node.value.name() + " node\n")
              .cstring())

            let next_initializer: StepInitializer = next_node.value

            ///////////////////////////////////////////////////////////////////
            // Determine if the next initializer is for a step, sink, or source
            match next_initializer
            | let builder: StepBuilder =>
            ///////////////
            // STEP BUILDER
            ///////////////
              @printf[I32](("----Spinning up " + builder.name() + "----\n")
                .cstring())
              // Each worker has its own execution ids assigned for a given
              // node id. For example, if this is a parallel stateless
              // computation, then there will be an execution id for each
              // of the n steps that must be created given a parallelism of n.
              let node_id = next_node.id
              let execution_ids = t.routing_ids()(node_id)?

              let out_ids: Array[RoutingId] val =
                try
                  _get_output_node_ids(next_node)?
                else
                  @printf[I32]("Failed to get output node ids\n".cstring())
                  error
                end

              // Determine router for outputs from this computation.
              let out_router =
                if out_ids.size() > 0 then
                  let routers = recover iso Array[Router] end
                  for id in out_ids.values() do
                    try
                      routers.push(built_routers(id)?)
                    else
                      @printf[I32]("No router found to target\n".cstring())
                      error
                    end
                  end
                  ifdef debug then
                    Invariant(routers.size() > 0)
                  end
                  if routers.size() == 1 then
                    routers(0)?
                  else
                    MultiRouter(consume routers)
                  end
                else
                  // There should be at least one output for a stateless
                  // computation.
                  Fail()
                  EmptyRouter
                end

              if builder.is_stateful() then
                //////////////////////////////////
                // STATE COMPUTATION
                let state_name =
                  match builder.routing_group()
                  | let sn: StateName => sn
                  else
                    Fail()
                    ""
                  end

                /////////
                // Create n steps given a parallelism of n. Then use these
                // to create a StatePartitionRouter.
                let step_group = create_step_group(execution_ids,
                  builder, out_router)

                // Now that we've built all the individual local steps in this
                // group, we need to record that we built this group and
                // then create the StatelessPartitionRouter that routes
                // messages to it.
                let router_state_steps_iso = recover iso Array[Step] end
                let router_state_step_ids_iso =
                  recover iso Map[RoutingId, Step] end
                for (r_id, next_step) in step_group.pairs() do
                  router_state_steps_iso.push(next_step)
                  router_state_step_ids_iso(r_id) = next_step
                  data_routes(r_id) = next_step
                  _initializables.set(next_step)
                end
                let router_state_steps = consume val router_state_steps_iso
                let router_state_step_ids =
                  consume val router_state_step_ids_iso
                built_state_steps(state_name) = router_state_steps

                // Create HashedProxyRouters to other workers involved in this
                // state computation step group.
                // TODO: Currently, we simply include all workers in the
                // cluster, but eventually we will need a more intelligent
                // layout.
                let proxies =
                  recover iso Map[WorkerName, HashedProxyRouter] end
                for (w, ob) in _outgoing_boundaries.pairs() do
                  proxies(w) = HashedProxyRouter(w, ob, state_name, _auth)
                end

                let next_router = StatePartitionRouter(state_name,
                  _worker_name, router_state_steps, router_state_step_ids,
                  consume proxies, HashPartitions(t.worker_names),
                  t.state_routing_ids(state_name)?)

                state_partition_routers(state_name) = next_router
                built_routers(node_id) = next_router
              else
                //////////////////////////////////
                // STATELESS COMPUTATION
                let partition_routing_id: RoutingId =
                  match builder.routing_group()
                  | let ri: RoutingId => ri
                  else
                    Fail()
                    0
                  end

                /////////
                // Create n steps given a parallelism of n. Then use these
                // to create a StatelessPartitionRouter.
                let step_group = create_step_group(execution_ids,
                  builder, out_router)

                // Now that we've built all the individual local steps in this
                // group, we need to record that we built this group and
                // then create the StatelessPartitionRouter that routes
                // messages to it.
                let router_stateless_steps_iso = recover iso Array[Step] end
                let router_stateless_step_ids_iso =
                  recover iso MapIs[Step, RoutingId] end
                for (r_id, next_step) in step_group.pairs() do
                  router_stateless_steps_iso.push(next_step)
                  router_stateless_step_ids_iso(next_step) = r_id
                  data_routes(r_id) = next_step
                  _initializables.set(next_step)
                end
                let router_stateless_steps =
                  consume val router_stateless_steps_iso
                let router_stateless_step_ids =
                  consume val router_stateless_step_ids_iso
                built_stateless_steps(partition_routing_id) =
                  router_stateless_steps

                // Create proxies to other workers involved in this
                // stateless computation step group.
                // TODO: Currently, we simply include all workers in the
                // cluster, but eventually we will need a more intelligent
                // layout.
                let proxies = recover iso Map[WorkerName, ProxyRouter] end
                for (w, ob) in _outgoing_boundaries.pairs() do
                  let w_routing_id =
                    t.stateless_partition_routing_ids(partition_routing_id)?(
                      w)?
                  let proxy_address = ProxyAddress(w, w_routing_id)
                  let proxy_router = ProxyRouter(_worker_name, ob,
                    proxy_address, _auth)
                  proxies(w) = proxy_router
                end

                let next_router = StatelessPartitionRouter(
                  partition_routing_id, _worker_name, t.worker_names,
                  router_stateless_steps, router_stateless_step_ids,
                  t.stateless_partition_routing_ids(partition_routing_id)?,
                  consume proxies, execution_ids.size())

                stateless_partition_routers(partition_routing_id) = next_router
                built_routers(node_id) = next_router
              end
            | let egress_builder: EgressBuilder =>
            ////////////////////////////////////
            // EGRESS BUILDER (Sink)
            ////////////////////////////////////
              let next_id = egress_builder.id()

              let sink_reporter = MetricsReporter(t.name(), _worker_name,
                _metrics_conn)

              // TODO: We should be passing in a RoutingId from our
              // execution ids list, but right now the SinkBuilder
              // infrastructure doesn't allow that. This means that currently
              // the same sink_id is attached to sink replicas across workers.
              let sink = egress_builder(_worker_name, consume sink_reporter,
                _event_log, _recovering, _barrier_initiator,
                _checkpoint_initiator, _env, _auth,
                _outgoing_boundaries)

              _connections.register_disposable(sink)
              _initializables.set(sink)

              //!@ I don't think we need this
              // built_stateless_steps(next_id) = [sink]

              data_routes(next_id) = sink

              let sink_router = DirectRouter(next_id, sink)
              built_routers(next_id) = sink_router
            | let source_data: SourceData =>
            /////////////////
            // SOURCE DATA
            /////////////////
              let next_id = source_data.id()
              let pipeline_name = source_data.pipeline_name()

              let out_ids: Array[RoutingId] val =
                try
                  _get_output_node_ids(next_node)?
                else
                  @printf[I32]("Failed to get output node ids\n".cstring())
                  error
                end

              // Determine router for outputs from this source.
              let out_router =
                if out_ids.size() > 0 then
                  let routers = recover iso Array[Router] end
                  for id in out_ids.values() do
                    try
                      routers.push(built_routers(id)?)
                    else
                      @printf[I32]("No router found to target\n".cstring())
                      error
                    end
                  end
                  ifdef debug then
                    Invariant(routers.size() > 0)
                  end
                  if routers.size() == 1 then
                    routers(0)?
                  else
                    MultiRouter(consume routers)
                  end
                else
                  // There should be at least one output for a stateless
                  // computation.
                  Fail()
                  EmptyRouter
                end

              // If there is no BarrierSource, we need to create one, since
              // this worker has at least one Source on it.
              if barrier_source is None then
                let b_reporter = MetricsReporter(t.name(), _worker_name,
                  _metrics_conn)
                let b_source = BarrierSource(t.barrier_source_id,
                  _router_registry, _event_log, consume b_reporter)
                _barrier_initiator.register_barrier_source(b_source)
                barrier_source = b_source
              end
              try
                (barrier_source as BarrierSource).register_pipeline(
                  pipeline_name, out_router)
              else
                Unreachable()
              end

              let source_reporter = MetricsReporter(t.name(), _worker_name,
                _metrics_conn)

              let listen_auth = TCPListenAuth(_auth)
              @printf[I32](("----Creating source for " + pipeline_name +
                " pipeline with " + source_data.name() + "----\n").cstring())

              // Set up SourceListener builders
              let source_runner_builder = source_data.runner_builder()
              let sl_builder_builder =
                source_data.source_listener_builder_builder()
              let sl_builder = sl_builder_builder(_worker_name,
                pipeline_name, source_runner_builder, out_router,
                _metrics_conn, consume source_reporter, _router_registry,
                _outgoing_boundary_builders, _event_log, _auth, this,
                _recovering)
              sl_builders.push(sl_builder)

              // Nothing connects to a source via an in edge locally,
              // so this just marks that we've built this one
              built_routers(next_id) = EmptyRouter
            end
            @printf[I32](("Finished handling " + next_node.value.name() +
              " node\n").cstring())
          else
            nodes_to_initialize.push(next_node)
          end
        end

        //////////////////////////////////////////////////////////////////////
        // 3. Create DataRouter, register components with RouterRegistry,
        //    and initiate final initialization Phases.

        ////////////////////////////////////////////
        // Set up the DataRouter for this worker
        for (_, steps) in built_state_steps.pairs() do
          for s in steps.values() do
            _router_registry.register_producer(s)
          end
        end
        for (_, steps) in built_stateless_steps.pairs() do
          for s in steps.values() do
            _router_registry.register_producer(s)
          end
        end

        let sendable_data_routes = consume val data_routes

        let state_steps_iso = recover iso Map[StateName, Array[Step] val] end
        for (k, v) in built_state_steps.pairs() do
          state_steps_iso(k) = v
        end
        let sendable_state_steps = consume val state_steps_iso

        let stateless_steps_iso =
          recover iso Map[RoutingId, Array[Step] val] end
        for (k, v) in built_stateless_steps.pairs() do
          stateless_steps_iso(k) = v
        end
        let sendable_stateless_steps = consume val stateless_steps_iso

        let data_router_state_routing_ids =
          recover iso Map[RoutingId, StateName] end
        for (s_name, ws) in t.state_routing_ids.pairs() do
          for (w, r_id) in ws.pairs() do
            if w == _worker_name then
              data_router_state_routing_ids(r_id) = s_name
            end
          end
        end

        let data_router_stateless_routing_ids =
          recover iso Map[RoutingId, RoutingId] end
        for (sr_id, ws) in t.stateless_partition_routing_ids.pairs() do
          for (w, r_id) in ws.pairs() do
            if w == _worker_name then
              data_router_stateless_routing_ids(r_id) = sr_id
            end
          end
        end

        let data_router = DataRouter(_worker_name, sendable_data_routes,
          sendable_state_steps, sendable_stateless_steps,
          consume data_router_state_routing_ids,
          consume data_router_stateless_routing_ids)
        _router_registry.set_data_router(data_router)
        _data_receivers.update_data_router(data_router)

        ////////////////////////////
        // For non-initializers, inform the initializer that we're done
        // initializing our local topology. If this is the initializer worker,
        // we'll inform our ClusterInitializer actor once we've spun up the
        // source listeners. Joining workers don't take part in this protocol.
        if (not _is_initializer) and (not _is_joining) then
          let topology_ready_msg =
            try
              ChannelMsgEncoder.topology_ready(_worker_name, _auth)?
            else
              @printf[I32]("ChannelMsgEncoder failed\n".cstring())
              error
            end

          if not _recovering then
            _connections.send_control("initializer", topology_ready_msg)
          end
        end

        //////////////////////////////////////////////////////////////////
        // Register boundaries and partition routers with RouterRegistry
        _router_registry.register_boundaries(_outgoing_boundaries,
          _outgoing_boundary_builders)

        for (s_name, pr) in state_partition_routers.pairs() do
          _router_registry.set_state_partition_router(s_name, pr)
        end

        for (id, pr) in stateless_partition_routers.pairs() do
          _router_registry.set_stateless_partition_router(id, pr)
        end

        /////////////////////////////////////////
        // Kick off final initialization Phases
        _initializables.application_begin_reporting(this)

        @printf[I32]("Local topology initialized\n".cstring())
        _topology_initialized = true

        if _initializables.size() == 0 then
          @printf[I32](("Phases I-II skipped (this topology must only have " +
            "sources.)\n").cstring())
          _application_ready_to_work()
        end

        if recovering_without_resilience then
          _data_receivers.recovery_complete()
        end
      else
        @printf[I32](("Local Topology Initializer: No local topology to " +
          "initialize\n").cstring())
      end

      @printf[I32]("\n|^|^|^|Finished Initializing Local Topology|^|^|^|\n"
        .cstring())
      @printf[I32]("---------------------------------------------------------\n".cstring())
    else
      @printf[I32]("Error initializing topology!\n".cstring())
      Fail()
    end

  fun create_step_group(routing_ids: SetIs[RoutingId] box,
    builder: StepBuilder, output_router: Router): Map[RoutingId, Step]
  =>
    let steps = Map[RoutingId, Step]
    for r_id in routing_ids.values() do
      let next_step = builder(r_id, _worker_name, output_router,
        _metrics_conn, _event_log, _recovery_replayer, _auth,
        _outgoing_boundaries, _router_registry)

      steps(r_id) = next_step
      _connections.register_disposable(next_step)

      // If our outputs are going to be routed through a
      // StatePartitionRouter or StatelessPartitionRouter, then we
      // need to subscribe to updates to that router.
      // ASSUMPTION: If an out_router is a MultiRouter, then none
      // of its subrouters are partition routers. Put differently,
      // we assume that splits never include partition routers.
      match output_router
      | let pr: StatePartitionRouter =>
        _router_registry
          .register_partition_router_subscriber(pr.state_name(),
            next_step)
      | let pr: StatelessPartitionRouter =>
        _router_registry
          .register_stateless_partition_router_subscriber(
            pr.partition_routing_id(), next_step)
      end
    end
    steps

  fun _is_ready_for_building(node: DagNode[StepInitializer] val,
    built_routers: Map[U128, Router]): Bool
  =>
    var is_ready = true
    for out in node.outs() do
      if not built_routers.contains(out.id) then is_ready = false end
    end
    is_ready

  fun _get_output_node_ids(node: DagNode[StepInitializer] val):
    Array[RoutingId] val ?
  =>
    // Make sure this is not a sink or proxy node.
    match node.value
    | let eb: EgressBuilder =>
      @printf[I32](("Sinks and Proxies have no output nodes in the local " +
        "graph!\n").cstring())
      error
    end

    var out_ids = recover iso Array[RoutingId] end
    for out in node.outs() do
      out_ids.push(out.id)
    end
    consume out_ids


//////////////////////////
// INITIALIZATION PHASES
//////////////////////////
  be initialize_join_initializables() =>
    _initialize_join_initializables()

  fun ref _initialize_join_initializables() =>
    // For now we need to keep boundaries out of the initialization
    // lifecycle stages during join. This is because during a join, all
    // data channels are muted, so we are not able to connect
    // over boundaries. This means the boundaries can not
    // report as initialized until the join is complete, but
    // the join can't complete until we say we're initialized.
    _initializables.remove_boundaries()
    _initializables.application_begin_reporting(this)
    if _initializables.size() == 0 then
      _complete_initialization_lifecycle()
    end

  be report_created(initializable: Initializable) =>
    if not _created.contains(initializable) then
      _created.set(initializable)
      if _created.size() == _initializables.size() then
        @printf[I32]("|~~ INIT PHASE I: Application is created! ~~|\n"
          .cstring())
        _spin_up_source_listeners()
        _initializables.application_created(this)
      end
    else
      @printf[I32]("The same Initializable reported being created twice\n"
        .cstring())
      Fail()
    end

  be report_initialized(initializable: Initializable) =>
    if not _initialized.contains(initializable) then
      _initialized.set(initializable)
      if _initialized.size() == _initializables.size() then
        @printf[I32]("|~~ INIT PHASE II: Application is initialized! ~~|\n"
          .cstring())
        _initializables.application_initialized(this)
      end
    else
      @printf[I32]("The same Initializable reported being initialized twice\n"
        .cstring())
      //!@ Bring this back and solve bug
      // Fail()
    end

  be report_ready_to_work(initializable: Initializable) =>
    if not _ready_to_work.contains(initializable) then
      _ready_to_work.set(initializable)
      if (not _initialization_lifecycle_complete) and
        (_ready_to_work.size() == _initializables.size())
      then
        _complete_initialization_lifecycle()
      end
    else
      @printf[I32](("The same Initializable reported being ready to work " +
        "twice\n").cstring())
      Fail()
    end

  fun ref _complete_initialization_lifecycle() =>
    match _topology
    | let t: LocalTopology =>
      if _recovering then
        _recovery.start_recovery(this, t.worker_names)
      else
        _recovery_ready_to_work = true
        _event_log.quick_initialize(this)
      end
      _router_registry.application_ready_to_work()
      if _is_joining then
        // Call this on router registry instead of Connections directly
        // to make sure that other messages on registry queues are
        // processed first
        _router_registry.inform_contacted_worker_of_initialization(
          t.state_routing_ids_for(_worker_name),
          t.stateless_partition_routing_ids_for(_worker_name))
      end
      _initialization_lifecycle_complete = true
    else
      Fail()
    end

  be report_event_log_ready_to_work() =>
    _event_log_ready_to_work = true
    // This should only get called after all initializables have reported
    // they are ready to work, at which point we would have told the EventLog
    // to start pipeline logging.
    Invariant(_ready_to_work.size() == _initializables.size())

    if _recovery_ready_to_work then
      _application_ready_to_work()
    end

  be report_recovery_ready_to_work() =>
    _recovery_ready_to_work = true
    if _event_log_ready_to_work then
      _application_ready_to_work()
    end

  fun ref _application_ready_to_work() =>
    @printf[I32]("|~~ INIT PHASE III: Application is ready to work! ~~|\n"
      .cstring())
    _initializables.application_ready_to_work(this)

    if _is_initializer then
      match _cluster_initializer
      | let ci: ClusterInitializer =>
        ci.topology_ready("initializer")
        _is_initializer = false
      else
        @printf[I32](("Need ClusterInitializer to inform that topology is " +
          "ready\n").cstring())
      end
    end

  fun ref _spin_up_source_listeners() =>
    if not _topology_initialized then
      @printf[I32](("ERROR: Tried to spin up source listeners before " +
        "topology was initialized!\n").cstring())
    else
      for builder in sl_builders.values() do
        let sl = builder(_env)
        _router_registry.register_source_listener(sl)
      end
    end


///////////////////////
// RESILIENCE
///////////////////////
  be rollback_local_keys(checkpoint_id: CheckpointId,
    promise: Promise[None])
  =>
    @printf[I32]("Rolling back topology graph.\n".cstring())
    let local_keys = _local_keys_file.read_local_keys(checkpoint_id)
    _router_registry.rollback_keys(local_keys, promise)

  be recover_and_initialize(ws: Array[WorkerName] val,
    cluster_initializer: (ClusterInitializer | None) = None)
  =>
    _recovering = true
    _recovered_worker_names = ws

    try
      let data_channel_filepath = FilePath(_auth, _data_channel_file)?
      if not _is_initializer then
        let data_notifier: DataChannelListenNotify iso =
          DataChannelListenNotifier(_worker_name, _auth, _connections,
            _is_initializer,
            MetricsReporter(_app_name, _worker_name,
              _metrics_conn),
            data_channel_filepath, this, _data_receivers, _recovery_replayer,
            _router_registry, _the_journal, _do_local_file_io)

        _connections.make_and_register_recoverable_data_channel_listener(
          _auth, consume data_notifier, _router_registry,
          data_channel_filepath)
      else
        match cluster_initializer
        | let ci: ClusterInitializer =>
          _connections.create_initializer_data_channel_listener(
            _data_receivers, _recovery_replayer, _router_registry, ci,
            data_channel_filepath, this)
        end
      end
    else
      @printf[I32]("FAIL: cannot create data channel\n".cstring())
    end

  be register_key(state_name: StateName, key: Key,
    checkpoint_id: (CheckpointId | None) = None)
  =>
    // We only add an entry to the local keys file if this is part of a
    // checkpoint.
    match checkpoint_id
    | let c_id: CheckpointId =>
      _local_keys_file.add_key(state_name, key, c_id)
    end

  be unregister_key(state_name: StateName, key: Key,
    checkpoint_id: (CheckpointId | None) = None)
  =>
    // We only add an entry to the local keys file if this is part of a
    // checkpoint.
    match checkpoint_id
    | let c_id: CheckpointId =>
      _local_keys_file.remove_key(state_name, key, c_id)
    end

  fun ref _save_worker_names()
  =>
    """
    Save the list of worker names to a file.
    """
    try
      match _topology
      | let t: LocalTopology =>
        @printf[I32](("Saving worker names to file: " + _worker_names_file +
          "\n").cstring())
        let worker_names_filepath = FilePath(_auth, _worker_names_file)?
        let file = AsyncJournalledFile(worker_names_filepath, _the_journal, _auth, _do_local_file_io)
        // Clear file
        file.set_length(0)
        for worker_name in t.worker_names.values() do
          file.print(worker_name)
          @printf[I32](("LocalTopology._save_worker_names: " + worker_name +
          "\n").cstring())
        end
        file.sync()
        file.dispose()
        // TODO: AsyncJournalledFile does not provide implicit sync semantics here
      else
        Fail()
      end
    else
      Fail()
    end

  fun ref _save_local_topology() =>
    match _topology
    | let t: LocalTopology =>
      @printf[I32]("Saving topology!\n".cstring())
      try
        let local_topology_file = try
          FilePath(_auth, _local_topology_file)?
        else
          @printf[I32]("Error opening topology file!\n".cstring())
          Fail()
          error
        end
        // TODO: Back up old file before clearing it?
        let file = AsyncJournalledFile(local_topology_file, _the_journal,
          _auth, _do_local_file_io)
        // Clear contents of file.
        file.set_length(0)
        let wb = Writer
        let sa = SerialiseAuth(_auth)
        let s = try
          Serialised(sa, t)?
        else
          @printf[I32]("Error serializing topology!\n".cstring())
          Fail()
          error
        end
        let osa = OutputSerialisedAuth(_auth)
        let serialised_topology: Array[U8] val = s.output(osa)
        wb.write(serialised_topology)
        file.writev(recover val wb.done() end)
        file.sync()
        file.dispose()
        // TODO: AsyncJournalledFile does not provide implicit sync semantics here
      else
        @printf[I32]("Error saving topology!\n".cstring())
        Fail()
      end
    else
      @printf[I32]("Error saving topology!\n".cstring())
      Fail()
    end


///////////////////////
// AUTOSCALE
///////////////////////
  be request_new_worker() =>
    try
      (_cluster_manager as ClusterManager).request_new_worker()
    else
      @printf[I32](("Attempting to request a new worker but cluster manager is"
        + " None").cstring())
    end

  be receive_immigrant_key(msg: KeyMigrationMsg) =>
    _router_registry.receive_immigrant_key(msg)

  be ack_migration_batch_complete(sender: String) =>
    _router_registry.ack_migration_batch_complete(sender)

  be worker_join(conn: TCPConnection, joining_worker_name: String,
    joining_worker_count: USize)
  =>
    """
    Should only be called when a new worker initially contacts the cluster to
    join. This should not be called on any other worker than the one initially
    contacted.
    """
    match _topology
    | let t: LocalTopology =>
      let current_worker_count = t.worker_names.size()
      let new_t = t.add_new_worker(joining_worker_name)
      _router_registry.worker_join(conn, joining_worker_name,
        joining_worker_count, new_t, current_worker_count)
    else
      Fail()
    end

  be connect_to_joining_workers(coordinator: String,
    control_addrs: Map[WorkerName, (String, String)] val,
    data_addrs: Map[WorkerName, (String, String)] val,
    new_state_routing_ids: Map[WorkerName, Map[StateName, RoutingId] val] val,
    new_stateless_partition_routing_ids:
      Map[WorkerName, Map[RoutingId, RoutingId] val] val)
  =>
    let new_workers = recover iso Array[WorkerName] end
    for w in control_addrs.keys() do new_workers.push(w) end
    _router_registry.connect_to_joining_workers(consume new_workers,
      new_state_routing_ids, new_stateless_partition_routing_ids, coordinator)

    for w in control_addrs.keys() do
      try
        let host = control_addrs(w)?._1
        let control_addr = control_addrs(w)?
        let data_addr = data_addrs(w)?
        let state_routing_ids = new_state_routing_ids(w)?
        let stateless_partition_routing_ids =
          new_stateless_partition_routing_ids(w)?
        _add_joining_worker(w, host, control_addr, data_addr,
          state_routing_ids, stateless_partition_routing_ids)
      else
        Fail()
      end
    end
    _save_local_topology()

  be add_joining_worker(w: WorkerName, joining_host: String,
    control_addr: (String, String), data_addr: (String, String),
    state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    _add_joining_worker(w, joining_host, control_addr, data_addr,
      state_routing_ids, stateless_partition_routing_ids)
    _save_local_topology()

  fun ref _add_joining_worker(w: WorkerName, joining_host: String,
    control_addr: (String, String), data_addr: (String, String),
    state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    match _topology
    | let t: LocalTopology =>
      if not ArrayHelpers[String].contains[String](t.worker_names, w) then
        let updated_topology = t.add_new_worker(w, state_routing_ids,
          stateless_partition_routing_ids)
        _topology = updated_topology
        _save_local_topology()
        _save_worker_names()
        _connections.create_control_connection(w, joining_host,
          control_addr._2)
        let new_boundary_id = _routing_id_gen()
        _connections.create_data_connection_to_joining_worker(w,
          joining_host, data_addr._2, new_boundary_id, state_routing_ids,
          stateless_partition_routing_ids, this)
        _connections.save_connections()
        @printf[I32]("***New worker %s added to cluster!***\n".cstring(),
          w.cstring())
      end
    else
      Fail()
    end

  be initiate_shrink(target_workers: Array[WorkerName] val, shrink_count: U64,
    conn: TCPConnection)
  =>
    if target_workers.size() > 0 then
      if _are_valid_shrink_candidates(target_workers) then
        let remaining_workers = _remove_worker(target_workers)
        _router_registry.inject_shrink_autoscale_barrier(remaining_workers,
          target_workers)
        let reply = ExternalMsgEncoder.shrink_error_response(
          "Shrinking by " + target_workers.size().string() + " workers!")
        conn.writev(reply)
      else
        @printf[I32]("**Invalid shrink targets!**\n".cstring())
        let error_reply = ExternalMsgEncoder.shrink_error_response(
          "Invalid shrink targets!")
        conn.writev(error_reply)
      end
    elseif shrink_count > 0 then
      let candidates = _get_shrink_candidates(shrink_count.usize())
      if candidates.size() < shrink_count.usize() then
        @printf[I32]("**Only %s candidates are eligible for removal\n"
          .cstring(), candidates.size().string().cstring())
      else
        @printf[I32]("**%s candidates are eligible for removal\n"
          .cstring(), candidates.size().string().cstring())
      end
      if candidates.size() > 0 then
        let remaining_workers = _remove_worker(candidates)
        _router_registry.inject_shrink_autoscale_barrier(remaining_workers,
          candidates)
        let reply = ExternalMsgEncoder.shrink_error_response(
          "Shrinking by " + candidates.size().string() + " workers!")
        conn.writev(reply)
      else
        @printf[I32]("**Cannot shrink 0 workers!**\n".cstring())
        let error_reply = ExternalMsgEncoder.shrink_error_response(
          "Cannot shrink 0 workers!")
        conn.writev(error_reply)
      end
    else
      @printf[I32]("**Cannot shrink 0 workers!**\n".cstring())
      let error_reply = ExternalMsgEncoder.shrink_error_response(
        "Cannot shrink 0 workers!")
      conn.writev(error_reply)
    end

  be take_over_initiate_shrink(remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _remove_worker(leaving_workers)
    _router_registry.inject_shrink_autoscale_barrier(remaining_workers,
      leaving_workers)

  be prepare_shrink(remaining_workers: Array[WorkerName] val,
    leaving_workers: Array[WorkerName] val)
  =>
    _remove_worker(leaving_workers)
    _router_registry.prepare_shrink(remaining_workers, leaving_workers)

  be remove_worker_connection_info(worker: WorkerName) =>
    _connections.remove_worker_connection_info(worker)
    _connections.save_connections()

  fun _are_valid_shrink_candidates(candidates: Array[WorkerName] val): Bool =>
    match _topology
    | let t: LocalTopology =>
      for c in candidates.values() do
        // A worker name is not a valid candidate if it is non shrinkable
        // or if it's not in the current cluster.
        if SetHelpers[String].contains[String](t.non_shrinkable, c) or
          (not ArrayHelpers[String].contains[String](t.worker_names, c))
        then
          return false
        end
      end
      true
    else
      Fail()
      false
    end

  fun _get_shrink_candidates(count: USize): Array[WorkerName] val =>
    let candidates = recover trn Array[String] end
    match _topology
    | let t: LocalTopology =>
      for w in t.worker_names.values() do
        if candidates.size() < count then
          if not SetHelpers[String].contains[String](t.non_shrinkable, w) then
            candidates.push(w)
          end
        end
      end
    else
      Fail()
    end
    consume candidates

  be add_boundary_to_joining_worker(w: WorkerName, boundary: OutgoingBoundary,
    builder: OutgoingBoundaryBuilder,
    state_routing_ids: Map[StateName, RoutingId] val,
    stateless_partition_routing_ids: Map[RoutingId, RoutingId] val)
  =>
    _add_boundary(w, boundary, builder)
    _router_registry.register_boundaries(_outgoing_boundaries,
      _outgoing_boundary_builders)
    _router_registry.joining_worker_initialized(w, state_routing_ids,
      stateless_partition_routing_ids)

  fun ref _remove_worker(ws: Array[WorkerName] val): Array[WorkerName] val =>
    match _topology
    | let t: LocalTopology =>
      let new_topology = t.remove_worker(ws)
      _topology = new_topology
      _save_local_topology()
      _save_worker_names()
      new_topology.worker_names
    else
      Fail()
      recover val Array[WorkerName] end
    end

  fun ref _add_boundary(target_worker: WorkerName, boundary: OutgoingBoundary,
    builder: OutgoingBoundaryBuilder)
  =>
    // Boundaries
    let bs = recover trn Map[WorkerName, OutgoingBoundary] end
    for (w, b) in _outgoing_boundaries.pairs() do
      bs(w) = b
    end
    bs(target_worker) = boundary

    // Boundary builders
    let bbs = recover trn Map[WorkerName, OutgoingBoundaryBuilder] end
    for (w, b) in _outgoing_boundary_builders.pairs() do
      bbs(w) = b
    end
    bbs(target_worker) = builder

    _outgoing_boundaries = consume bs
    _outgoing_boundary_builders = consume bbs
    _initializables.set(boundary)

  be remove_boundary(leaving_worker: WorkerName) =>
    // Boundaries
    let bs = recover trn Map[WorkerName, OutgoingBoundary] end
    for (w, b) in _outgoing_boundaries.pairs() do
      if w != leaving_worker then bs(w) = b end
    end

    // Boundary builders
    let bbs = recover trn Map[WorkerName, OutgoingBoundaryBuilder] end
    for (w, b) in _outgoing_boundary_builders.pairs() do
      if w != leaving_worker then bbs(w) = b end
    end
    _outgoing_boundaries = consume bs
    _outgoing_boundary_builders = consume bbs


///////////////////////
// EXTERNAL QUERIES
///////////////////////
  be shrinkable_query(conn: TCPConnection) =>
    let available = recover iso Array[String] end
    match _topology
    | let t: LocalTopology =>
      for w in t.worker_names.values() do
        if not SetHelpers[String].contains[String](t.non_shrinkable, w) then
          available.push(w)
        end
      end
      let size = available.size()
      let query_reply = ExternalMsgEncoder.shrink_query_response(
        consume available, size.u64())
      conn.writev(query_reply)
    else
      Fail()
    end

  be partition_query(conn: TCPConnection) =>
    _router_registry.partition_query(conn)

  be partition_count_query(conn: TCPConnection) =>
    _router_registry.partition_count_query(conn)

  be cluster_status_query(conn: TCPConnection) =>
    if not _topology_initialized then
      _router_registry.cluster_status_query_not_initialized(conn)
    else
      match _topology
      | let t: LocalTopology =>
        _router_registry.cluster_status_query(t.worker_names, conn)
      else
        Fail()
      end
    end

  be source_ids_query(conn: TCPConnection) =>
    _router_registry.source_ids_query(conn)

  be state_entity_query(conn: TCPConnection) =>
    _router_registry.state_entity_query(conn)

  be stateless_partition_query(conn: TCPConnection) =>
    _router_registry.stateless_partition_query(conn)

  be state_entity_count_query(conn: TCPConnection) =>
    _router_registry.state_entity_count_query(conn)

  be stateless_partition_count_query(conn: TCPConnection) =>
    _router_registry.stateless_partition_count_query(conn)

  be report_status(code: ReportStatusCode) =>
    match code
    | BoundaryCountStatus =>
      @printf[I32]("LocalTopologyInitializer knows about %s boundaries\n"
        .cstring(), _outgoing_boundaries.size().string().cstring())
    end
    _router_registry.report_status(code)
