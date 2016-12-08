use "net"
use "collections"
use "promises"
use "serialise"
use "files"
use "buffered"
use "sendence/dag"
use "sendence/guid"
use "sendence/queue"
use "sendence/messages"
use "wallaroo"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/topology"
use "wallaroo/tcp-sink"
use "wallaroo/tcp-source"

class LocalTopology
  let _app_name: String
  let _worker_name: String
  let _graph: Dag[StepInitializer val] val
  let _step_map: Map[U128, (ProxyAddress val | U128)] val
  // _state_builders maps from state_name to StateSubpartition
  let _state_builders: Map[String, StateSubpartition val] val
  let _pre_state_data: Array[PreStateData val] val
  let _proxy_ids: Map[String, U128] val
  // TODO: Replace this default strategy with a better one after POC
  let default_target: (Array[StepBuilder val] val | ProxyAddress val | None)
  let default_state_name: String
  let default_target_id: U128

  new val create(name': String, worker_name: String,
    graph': Dag[StepInitializer val] val,
    step_map': Map[U128, (ProxyAddress val | U128)] val,
    state_builders': Map[String, StateSubpartition val] val,
    pre_state_data': Array[PreStateData val] val,
    proxy_ids': Map[String, U128] val,
    default_target': (Array[StepBuilder val] val | ProxyAddress val | None) =
      None,
    default_state_name': String = "", default_target_id': U128 = 0)
  =>
    _app_name = name'
    _worker_name = worker_name
    _graph = graph'
    _step_map = step_map'
    _state_builders = state_builders'
    _pre_state_data = pre_state_data'
    _proxy_ids = proxy_ids'
    // TODO: Replace this default strategy with a better one after POC
    default_target = default_target'
    default_state_name = default_state_name'
    default_target_id = default_target_id'

  fun update_state_map(state_name: String,
    state_map: Map[String, Router val],
    metrics_conn: TCPConnection, alfred: Alfred,
    connections: Connections, auth: AmbientAuth,
    outgoing_boundaries: Map[String, OutgoingBoundary] val,
    initializables: SetIs[Initializable tag],
    data_routes: Map[U128, CreditFlowConsumerStep tag],
    default_router: (Router val | None)) ?
  =>
    let subpartition =
      try
        _state_builders(state_name)
      else
        @printf[I32](("Tried to update state map with nonexistent state name " + state_name + "\n").cstring())
        error
      end

    if not state_map.contains(state_name) then
      @printf[I32](("----Creating state steps for " + state_name + "----\n").cstring())
      state_map(state_name) = subpartition.build(_app_name, _worker_name,
         metrics_conn, auth, connections, alfred, outgoing_boundaries,
         initializables, data_routes, default_router)
    end

  fun graph(): Dag[StepInitializer val] val => _graph

  fun pre_state_data(): Array[PreStateData val] val => _pre_state_data

  fun step_map(): Map[U128, (ProxyAddress val | U128)] val => _step_map

  fun name(): String => _app_name

  fun is_empty(): Bool =>
    _graph.is_empty()

  fun proxy_ids(): Map[String, U128] val => _proxy_ids

actor LocalTopologyInitializer
  let _application: Application val
  let _input_addrs: Array[Array[String]] val
  let _worker_name: String
  let _worker_count: USize
  let _env: Env
  let _auth: AmbientAuth
  let _connections: Connections
  let _metrics_conn: TCPConnection
  let _alfred : Alfred tag
  var _is_initializer: Bool
  var _outgoing_boundaries: Map[String, OutgoingBoundary] val =
    recover Map[String, OutgoingBoundary] end
  var _topology: (LocalTopology val | None) = None
  let _data_receivers: Map[String, DataReceiver] = _data_receivers.create()
  let _local_topology_file: String
  var _worker_initializer: (WorkerInitializer | None) = None
  var _topology_initialized: Bool = false

  // Lifecycle
  var _omni_router: (OmniRouter val | None) = None
  var _tcp_sinks: Array[TCPSink] val = recover Array[TCPSink] end
  var _created: SetIs[Initializable tag] = _created.create()
  var _initialized: SetIs[Initializable tag] = _initialized.create()
  var _ready_to_work: SetIs[Initializable tag] = _ready_to_work.create()
  let _initializables: SetIs[Initializable tag] = _initializables.create()

  // Accumulate all TCPSourceListenerBuilders so we can build them
  // once Alfred signals we're ready
  let tcpsl_builders: Array[TCPSourceListenerBuilder val] =
    recover iso Array[TCPSourceListenerBuilder val] end

  new create(app: Application val, worker_name: String, worker_count: USize,
    env: Env, auth: AmbientAuth, connections: Connections,
    metrics_conn: TCPConnection, is_initializer: Bool, alfred: Alfred tag,
    input_addrs: Array[Array[String]] val, local_topology_file: String)
  =>
    _application = app
    _worker_name = worker_name
    _worker_count = worker_count
    _env = env
    _auth = auth
    _connections = connections
    _metrics_conn = metrics_conn
    _is_initializer = is_initializer
    _alfred = alfred
    _input_addrs = input_addrs
    _local_topology_file = local_topology_file

  be update_topology(t: LocalTopology val) =>
    _topology = t

  be update_boundaries(bs: Map[String, OutgoingBoundary] val) =>
    _outgoing_boundaries = bs

  be create_data_receivers(ws: Array[String] val,
    worker_initializer: (WorkerInitializer | None) = None) =>
    let drs: Map[String, DataReceiver] trn =
      recover Map[String, DataReceiver] end

    for w in ws.values() do
      if w != _worker_name then
        let data_receiver = DataReceiver(_auth, _worker_name, w, _connections,
          _alfred)
        drs(w) = data_receiver
        _data_receivers(w) = data_receiver
      end
    end

    let data_receivers: Map[String, DataReceiver] val = consume drs

    if not _is_initializer then
      let data_notifier: TCPListenNotify iso =
        DataChannelListenNotifier(_worker_name, _env, _auth, _connections,
          _is_initializer, data_receivers)
      _connections.register_listener(
        TCPListener(_auth, consume data_notifier))
    else
      match worker_initializer
      | let wi: WorkerInitializer =>
        _connections.create_initializer_data_channel(data_receivers, wi)
      end
    end

  be initialize(worker_initializer: (WorkerInitializer | None) = None) =>
    @printf[I32]("---------------------------------------------------------\n".cstring())
    @printf[I32]("|^|^|^Initializing Local Topology^|^|^|\n\n".cstring())
    _worker_initializer = worker_initializer
    try
      if (_worker_count > 1) and (_outgoing_boundaries.size() == 0) then
        @printf[I32]("Outgoing boundaries not set up!\n".cstring())
        error
      end

      ifdef "resilience" then
        try
          let local_topology_file = FilePath(_auth, _local_topology_file)
          if local_topology_file.exists() then
            //we are recovering an existing worker topology
            let data = recover val
              let file = File(local_topology_file)
              file.read(file.size())
            end
            match Serialised.input(InputSerialisedAuth(_auth), data)(
              DeserialiseAuth(_auth))
            | let t: LocalTopology val =>
              _topology = t
            else
              @printf[I32]("error restoring previous topology!".cstring())
            end
          end
        else
          @printf[I32]("error restoring previous topology!".cstring())
        end
      end

      match _topology
      | let t: LocalTopology val =>
        ifdef "resilience" then
          try
            let local_topology_file = FilePath(_auth, _local_topology_file)
            let file = File(local_topology_file)
            let wb = Writer
            let serialised_topology: Array[U8] val =
              Serialised(SerialiseAuth(_auth), _topology).output(
                OutputSerialisedAuth(_auth))
            wb.write(serialised_topology)
            file.writev(recover val wb.done() end)
          else
            @printf[I32]("error saving topology!".cstring())
          end
        end

        if t.is_empty() then
          @printf[I32]("----This worker has no steps----\n".cstring())
        end

        let graph = t.graph()

        @printf[I32]("Creating graph:\n".cstring())
        @printf[I32]((graph.string() + "\n").cstring())

        // Make sure we only create shared state once and reuse it
        let state_map: Map[String, Router val] = state_map.create()

        @printf[I32](("\nInitializing " + t.name() + " application locally:\n\n").cstring())

        // For passing into partition builders so they can add state steps
        // to our data routes
        let data_routes_ref = Map[U128, CreditFlowConsumerStep tag]

        // Keep track of all CreditFlowConsumerSteps by id so we can create a
        // DataRouter for the data channel boundary
        var data_routes: Map[U128, CreditFlowConsumerStep tag] trn =
          recover Map[U128, CreditFlowConsumerStep tag] end

        let tcp_sinks_trn: Array[TCPSink] trn = recover Array[TCPSink] end

        // Update the step ids for all OutgoingBoundaries
        _connections.update_boundary_ids(t.proxy_ids())

        // Keep track of routers to the steps we've built
        let built_routers = Map[U128, Router val]

        // Keep track of steps we've built that we'll use for the OmniRouter.
        // Unlike data_routes, these will not include state steps, which will // never be direct targets for state computation outputs.
        let built_stateless_steps: Map[U128, CreditFlowConsumerStep] trn =
          recover Map[U128, CreditFlowConsumerStep] end

        // TODO: Replace this when we move past the temporary POC based default
        // target strategy. There can currently only be one partition default // target per topology.
        var default_step_initializer: (StepInitializer val | None) = None
        var default_in_route_builder: (RouteBuilder val | None) = None
        var default_target: (Step | None) = None
        var default_target_id: U128 = t.default_target_id
        var default_target_state_step_id: U128 = 0
        var default_target_state_step: (Step | None) = None
        match t.default_target
        | let targets: Array[StepBuilder val] val =>
          @printf[I32]("A default target exists!\n".cstring())
          let pre_state_initializer =
            try
              targets(0)
            else
              @printf[I32]("No StepInitializer for prestate default target\n".cstring())
              error
            end

          default_step_initializer = pre_state_initializer
          default_in_route_builder = pre_state_initializer.in_route_builder()

          let state_builder =
            try
              targets(1)
            else
              @printf[I32]("No StepInitializer for state default target\n".cstring())
              error
            end
          default_target_state_step_id = state_builder.id()

          let state_step = state_builder(EmptyRouter, _metrics_conn,
            _alfred)
          state_step.update_route_builder(state_builder.forward_route_builder())

          default_target_state_step = state_step
          _initializables.set(state_step)

          let state_step_router = DirectRouter(state_step)
          built_routers(default_target_state_step_id) = state_step_router
          state_map(t.default_state_name) = state_step_router
        | let proxy_target: ProxyAddress val =>
          let proxy_router = ProxyRouter(_worker_name,
            _outgoing_boundaries(proxy_target.worker), proxy_target,
            _auth)
          built_routers(default_target_id) = proxy_router
        end

        /////////
        // Initialize based on DAG
        //
        // Assumptions:
        //   I. Acylic graph
        //   II. No splits (only joins), ignoring partitions
        //   III. No direct chains of different partitions
        /////////

        let frontier = Array[DagNode[StepInitializer val] val]

        /////////
        // 1. Find graph sinks and add to frontier queue.
        //    We'll work our way backwards.
        @printf[I32]("Adding sink nodes to frontier\n".cstring())

        // Hold non_partitions until the end because we need to build state
        // comp targets first. (Holding to the end means processing first,
        // since we're pushing onto a stack)
        let non_partitions = Array[DagNode[StepInitializer val] val]
        for node in graph.nodes() do
          if node.is_sink() and node.value.is_prestate() then
            @printf[I32](("Adding " + node.value.name() + " node to frontier\n").cstring())
            frontier.push(node)
          else
            non_partitions.push(node)
          end
        end

        for node in non_partitions.values() do
          @printf[I32](("Adding " + node.value.name() + " node to frontier\n").cstring())
          frontier.push(node)
        end

        /////////
        // 2. Loop: Check next frontier item for if all outgoing steps have
        //          been created
        //       if no, send to bottom of frontier stack.
        //       if yes, add ins to frontier stack, then build the step
        //       (connecting it to its out step, which has already been built)
        // If there are no cycles (I), this will terminate
        while frontier.size() > 0 do
          let next_node = frontier.pop()

          if built_routers.contains(next_node.id) then
            // We've already handled this node (probably because it's
            // pre-state)
            // TODO: I don't think this should ever happen.
            @printf[I32](("We've already handled " + next_node.value.name() + " with id " + next_node.id.string() + " so we're not handling it again\n").cstring())
            continue
          end

          // We are only ready to build a node if all of its outputs
          // have been built (though currently, because there are no
          // splits (II), there will only be at most one output per node)
          var ready = true
          for out in next_node.outs() do
            if not built_routers.contains(out.id) then ready = false end
          end
          match next_node.value
          | let s_builder: StepBuilder val =>
            match s_builder.pre_state_target_id()
            | let psid: U128 =>
              if not built_routers.contains(psid) then
                ready = false
              end
            end
          end
          if ready then
            @printf[I32](("Handling " + next_node.value.name() + " node\n").cstring())
            let next_initializer: StepInitializer val = next_node.value

            // ...match kind of initializer and go from there...
            match next_initializer
            | let builder: StepBuilder val =>
            ///////////////
            // STEP BUILDER
            ///////////////
              let next_id = builder.id()
              @printf[I32](("Handling id " + next_id.string() + "\n").cstring())

              if builder.is_prestate() then
              ///////////////////
              // PRESTATE BUILDER
                @printf[I32](("----Spinning up " + builder.name() + "----\n").cstring())

                // TODO: Change this when we implement post-POC default
                // strategy
                let dsn = builder.default_state_name()
                let default_router =
                  match default_step_initializer
                  | let dsinit: StepBuilder val =>
                    if (dsn != "") and (dsn == t.default_state_name) then
                      // We need a default router
                      let default_state_router = state_map(dsn)

                      let default_pre_state_id = dsinit.id()
                      let default_pre_state_step =
                        dsinit(default_state_router,
                          _metrics_conn, _alfred)
                      default_target = default_pre_state_step
                      _initializables.set(default_pre_state_step)
                      built_stateless_steps(default_pre_state_id) =
                        default_pre_state_step
                      data_routes(default_pre_state_id) = default_pre_state_step
                      let router = DirectRouter(default_pre_state_step)
                      built_routers(default_pre_state_id) = router
                      router
                    else
                      None
                    end
                  else
                    None
                  end

                ////
                // Create the state partition if it doesn't exist
                if builder.state_name() != "" then
                  t.update_state_map(builder.state_name(), state_map,
                    _metrics_conn, _alfred, _connections, _auth,
                    _outgoing_boundaries, _initializables,
                    data_routes_ref, default_router)
                end

                let partition_router =
                  try
                    builder.clone_router_and_set_input_type(
                      state_map(builder.state_name()), default_router)
                  else
                    // Not a partition, so we need a direct target router
                    @printf[I32](("No partition router found for " + builder.state_name() + "\n").cstring())
                    error
                  end

                let state_comp_target_router =
                  match builder.pre_state_target_id()
                  | let id: U128 =>
                    try
                      built_routers(id)
                    else
                      @printf[I32]("No router found to prestate target step\n".cstring())
                      error
                    end
                  else
                    // This prestate has no computation target
                    EmptyRouter
                  end

                let next_step = builder(partition_router, _metrics_conn,
                  _alfred, state_comp_target_router)

                data_routes(next_id) = next_step
                _initializables.set(next_step)

                built_stateless_steps(next_id) = next_step
                let next_router = DirectRouter(next_step)
                built_routers(next_id) = next_router
              elseif not builder.is_stateful() then
              //////////////////////////////////
              // STATELESS, NON-PRESTATE BUILDER
                @printf[I32](("----Spinning up " + builder.name() + "----\n").cstring())
                // Currently there are no splits (II), so we know that a node // has only one output in the graph. We also know this is not
                // a sink or proxy, so there is exactly one output.
                let out_id: U128 =
                    _get_output_node_id(next_node,
                      default_target_id, default_target_state_step_id)

                let out_router =
                  try
                    builder.clone_router_and_set_input_type(built_routers(out_id))
                  else
                    @printf[I32]("Invariant was violated: node was not built before one of its inputs.\n".cstring())
                    error
                  end

                // Check if this is a default target.  If so, route it
                // to the appropriate default state step.
                let next_step = builder(out_router, _metrics_conn, _alfred)

                data_routes(next_id) = next_step
                _initializables.set(next_step)

                built_stateless_steps(next_id) = next_step
                let next_router = DirectRouter(next_step)
                built_routers(next_id) = next_router

                // If this is our default target, then keep a reference
                // to it
                if next_id == default_target_id then
                  default_target = next_step
                end
              else
              ////////////////////////////////
              // NON-PARTITIONED STATE BUILDER
                // Our step is stateful and non-partitioned, so we need to
                // build both a state step and a prestate step

                // First, we must check that all state computation targets
                // have been built.  If they haven't, then we send this node
                // to the back of the frontier queue (it will eventually
                // be processed because of no splits (II))
                var targets_ready = true
                for in_node in next_node.ins() do
                  match in_node.value.pre_state_target_id()
                  | let id: U128 =>
                    try
                      built_routers(id)
                    else
                      targets_ready = false
                    end
                  end
                end

                if not targets_ready then
                  frontier.unshift(next_node)
                  continue
                end

                @printf[I32](("----Spinning up state for " + builder.name() + "----\n").cstring())
                let state_step = builder(EmptyRouter, _metrics_conn, _alfred)
                data_routes(next_id) = state_step
                _initializables.set(state_step)

                let state_step_router = DirectRouter(state_step)
                built_routers(next_id) = state_step_router

                // Before a non-partitioned state builder, we should
                // always have one or more non-partitioned pre-state builders.
                // The only inputs coming into a state builder should be
                // prestate builder, so we're going to build them all
                for in_node in next_node.ins() do
                  match in_node.value
                  | let b: StepBuilder val =>
                    @printf[I32](("----Spinning up " + b.name() + "----\n").cstring())

                    let state_comp_target =
                      match b.pre_state_target_id()
                      | let id: U128 =>
                        try
                          built_routers(id)
                        else
                          @printf[I32]("Prestate comp target not built! We should have already caught this\n".cstring())
                          error
                        end
                      else
                        @printf[I32]("There is no prestate comp target. Using an EmptyRouter\n".cstring())
                        EmptyRouter
                      end

                    let pre_state_step = b(state_step_router, _metrics_conn,
                      _alfred, state_comp_target)
                    data_routes(b.id()) = pre_state_step
                    _initializables.set(pre_state_step)

                    built_stateless_steps(b.id()) = pre_state_step
                    let pre_state_router = DirectRouter(pre_state_step)
                    built_routers(b.id()) = pre_state_router

                    state_step.register_routes(state_comp_target,
                      b.forward_route_builder())

                    // Add ins to this prestate node to the frontier
                    for in_in_node in in_node.ins() do
                      if not built_routers.contains(in_in_node.id) then
                        frontier.push(in_in_node)
                      end
                    end

                    @printf[I32](("Finished handling " + in_node.value.name() + " node\n").cstring())
                  else
                    @printf[I32]("State steps should only have prestate predecessors!\n".cstring())
                    error
                  end
                end
              end
            | let egress_builder: EgressBuilder val =>
            ////////////////////////////////////
            // EGRESS BUILDER (Sink or Boundary)
            ////////////////////////////////////
              let next_id = egress_builder.id()
              if not built_routers.contains(next_id) then
                let sink_reporter = MetricsReporter(t.name(),
                  _metrics_conn)

                // Create a sink or OutgoingBoundary proxy. If the latter,
                // egress_builder finds it from _outgoing_boundaries
                let sink = egress_builder(_worker_name,
                  consume sink_reporter, _auth, _outgoing_boundaries)

                match sink
                | let tcp: TCPSink =>
                  tcp_sinks_trn.push(tcp)
                end

                if not _initializables.contains(sink) then
                  _initializables.set(sink)
                end

                let sink_router =
                  match sink
                  | let ob: OutgoingBoundary =>
                    match egress_builder.target_address()
                    | let pa: ProxyAddress val =>
                      ProxyRouter(_worker_name, ob, pa, _auth)
                    else
                      @printf[I32]("No ProxyAddress for proxy!\n".cstring())
                      error
                    end
                  else
                    DirectRouter(sink)
                  end

                built_stateless_steps(next_id) = sink
                data_routes(next_id) = sink
                built_routers(next_id) = sink_router
              end
            | let source_data: SourceData val =>
            /////////////////
            // SOURCE DATA
            /////////////////
              let next_id = source_data.id()
              let pipeline_name = source_data.pipeline_name()

              // TODO: Change this when we implement post-POC default
              // strategy
              let dsn = source_data.default_state_name()
              let default_router =
                match default_step_initializer
                | let dsinit: StepBuilder val =>
                  if (dsn != "") and (dsn == t.default_state_name) then
                    // We need a default router
                    let default_state_router = state_map(dsn)

                    let default_pre_state_id = dsinit.id()
                    let default_pre_state_step =
                      dsinit(default_state_router,
                        _metrics_conn, _alfred)
                    default_target = default_pre_state_step
                    _initializables.set(default_pre_state_step)
                    built_stateless_steps(default_pre_state_id) =
                      default_pre_state_step
                    data_routes(default_pre_state_id) = default_pre_state_step
                    let router = DirectRouter(default_pre_state_step)
                    built_routers(default_pre_state_id) = router
                    router
                  else
                    None
                  end
                else
                  None
                end

              ////
              // Create the state partition if it doesn't exist
              if source_data.state_name() != "" then
                t.update_state_map(source_data.state_name(), state_map,
                  _metrics_conn, _alfred, _connections, _auth,
                  _outgoing_boundaries, _initializables,
                  data_routes_ref, default_router)
              end

              let state_comp_target_router =
                if source_data.is_prestate() then
                  match source_data.pre_state_target_id()
                  | let id: U128 =>
                    try
                      built_routers(id)
                    else
                      @printf[I32]("Prestate comp target not built! We should have already caught this\n".cstring())
                      error
                    end
                  else
                    @printf[I32]("There is no prestate comp target. Using an EmptyRouter\n".cstring())
                    EmptyRouter
                  end
                else
                  EmptyRouter
                end

              let out_router =
                if source_data.state_name() == "" then
                  // Currently there are no splits (II), so we know that a node has
                  // only one output in the graph. We also know this is not
                  // a sink or proxy, so there is exactly one output.
                  let out_id: U128 = _get_output_node_id(next_node,
                    default_target_id, default_target_state_step_id)
                  try
                    built_routers(out_id)
                  else
                    @printf[I32]("Invariant was violated: node was not built before one of its inputs.\n".cstring())
                    error
                  end
                else
                  // Source has a prestate runner on it, so we have no
                  // direct target. We need a partition router. And we
                  // need to register a route to our state comp target on those
                  // state steps.
                  try
                    source_data.clone_router_and_set_input_type(
                      state_map(source_data.state_name()), default_router)
                  else
                    @printf[I32]("State doesn't exist for state computation.\n".cstring())
                    error
                  end
                end

              let source_reporter = MetricsReporter(t.name(),
                _metrics_conn)

              // Get all the sinks so far, which should include any sinks
              // prestate on this source might target
              let sinks_for_source_trn: Array[TCPSink] trn =
                recover Array[TCPSink] end
              for sink in tcp_sinks_trn.values() do
                sinks_for_source_trn.push(sink)
              end
              let sinks_for_source: Array[TCPSink] val =
                consume sinks_for_source_trn

              let listen_auth = TCPListenAuth(_auth)
              try
                @printf[I32](("----Creating source for " + pipeline_name + " pipeline with " + source_data.name() + "----\n").cstring())
                tcpsl_builders.push(
                  TCPSourceListenerBuilder(
                    source_data.builder()(source_data.runner_builder(),
                      out_router, _metrics_conn,
                      source_data.pre_state_target_id()),
                    out_router,
                    source_data.route_builder(),
                    _outgoing_boundaries, sinks_for_source,
                    _alfred, default_target, default_in_route_builder,
                    state_comp_target_router,
                    source_data.address()(0),
                    source_data.address()(1))
                )
              else
                @printf[I32]("Ill-formed source address\n".cstring())
              end

              // Nothing connects to a source via an in edge locally,
              // so this just marks that we've built this one
              built_routers(next_id) = EmptyRouter
            end

            // Add all the nodes with incoming edges to next_node to the
            // frontier
            for in_node in next_node.ins() do
              if not built_routers.contains(in_node.id) then
                frontier.push(in_node)
              end
            end

            @printf[I32](("Finished handling " + next_node.value.name() + " node\n").cstring())
          else
            frontier.unshift(next_node)
          end
        end

        /////
        // Register pre state target routes on corresponding state steps
        for psd in t.pre_state_data().values() do
          match psd.target_id()
          | let tid: U128 =>
            // If the corresponding state has not been built yet, build it
            // now
            // TODO: Do we need a default router here?
            if psd.is_default_target() then
              match default_target_state_step
              | let ds: Step =>
                let target_router =
                  try
                    built_routers(tid)
                  else
                    @printf[I32]("Failed to build router for default target\n".cstring())
                    error
                  end
                ds.register_routes(target_router, psd.forward_route_builder())
              else
                @printf[I32]("Default targets are not built on this worker\n".cstring())
              end
            else
              if psd.state_name() != "" then
                t.update_state_map(psd.state_name(), state_map,
                  _metrics_conn, _alfred, _connections, _auth,
                  _outgoing_boundaries, _initializables,
                  data_routes_ref, None)
              end
              let partition_router =
                try
                  psd.clone_router_and_set_input_type(state_map(psd.state_name()))
                else
                  @printf[I32]("PartitionRouter was not built for expected state partition.\n".cstring())
                  error
                end
              let target_router = built_routers(tid)
              match partition_router
              | let pr: PartitionRouter val =>
                pr.register_routes(target_router, psd.forward_route_builder())
                @printf[I32](("Registered routes on state steps for " + psd.pre_state_name() + "\n").cstring())
              else
                @printf[I32](("Expected PartitionRouter but found something else!\n").cstring())
                error
              end
            end
          end
        end
        /////

        for (k, v) in data_routes_ref.pairs() do
          data_routes(k) = v
        end

        let data_router = DataRouter(consume data_routes)
        for receiver in _data_receivers.values() do
          receiver.update_router(data_router)
        end

        if not _is_initializer then
          // Inform the initializer that we're done initializing our local
          // topology. If this is the initializer worker, we'll inform
          // our WorkerInitializer actor once we've spun up the source
          // listeners.
          let topology_ready_msg =
            try
              ChannelMsgEncoder.topology_ready(_worker_name, _auth)
            else
              @printf[I32]("ChannelMsgEncoder failed\n".cstring())
              error
            end
          _connections.send_control("initializer", topology_ready_msg)

          let ready_msg = ExternalMsgEncoder.ready(_worker_name)
          _connections.send_phone_home(ready_msg)
        end

        let omni_router = StepIdRouter(_worker_name,
          consume built_stateless_steps, t.step_map(), _outgoing_boundaries)

        // Initialize all our initializables to get backpressure started
        _tcp_sinks = consume tcp_sinks_trn
        _omni_router = omni_router
        for i in _initializables.values() do
          i.application_begin_reporting(this)
        end

        @printf[I32]("Local topology initialized\n".cstring())
        _topology_initialized = true

        // TODO: Notify Alfred to start reading data. This should be called by // Alfred after it's done.
        _spin_up_source_listeners()
      else
        @printf[I32]("Local Topology Initializer: No local topology to initialize\n".cstring())
      end

      @printf[I32]("\n|^|^|^Finished Initializing Local Topology^|^|^|\n".cstring())
      @printf[I32]("---------------------------------------------------------\n".cstring())
    else
      _env.err.print("Error initializing local topology")
    end

  be report_created(initializable: Initializable tag) =>
    if not _created.contains(initializable) then
      match _omni_router
      | let o_router: OmniRouter val =>
        _created.set(initializable)
        if _created.size() == _initializables.size() then
          for i in _initializables.values() do
            i.application_created(this, _outgoing_boundaries, o_router)
          end
        end
      else
        Fail()
      end
    else
      @printf[I32]("The same Initializable reported being created twice\n".cstring())
      Fail()
    end

  be report_initialized(initializable: Initializable tag) =>
    if not _initialized.contains(initializable) then
      _initialized.set(initializable)
      if _initialized.size() == _initializables.size() then
        for i in _initializables.values() do
          i.application_initialized(this)
        end
      end
    else
      @printf[I32]("The same Initializable reported being initialized twice\n".cstring())
      Fail()
    end

  be report_ready_to_work(initializable: Initializable tag) =>
    if not _ready_to_work.contains(initializable) then
      _ready_to_work.set(initializable)
      if _ready_to_work.size() == _initializables.size() then
        _spin_up_source_listeners()
        for i in _initializables.values() do
          i.application_ready_to_work(this)
        end
      end
    else
      @printf[I32]("The same Initializable reported being ready to work twice\n".cstring())
      Fail()
    end

  fun ref _spin_up_source_listeners() =>
    if not _topology_initialized then
      @printf[I32]("ERROR: Tried to spin up source listeners before topology was initialized!\n".cstring())
    else
      for builder in tcpsl_builders.values() do
        builder()
      end
    end

    if _is_initializer then
      match _worker_initializer
      | let wi: WorkerInitializer =>
        wi.topology_ready("initializer")
        _is_initializer = false
      else
        @printf[I32]("Need WorkerInitializer to inform that topology is ready\n".cstring())
      end
    end

  fun _get_output_node_id(node: DagNode[StepInitializer val] val,
    default_target_id: U128, default_target_state_step_id: U128): U128 ?
  =>
    // TODO: Replace this once we move past POC default target strategy
    if node.id == default_target_id then
      @printf[I32]("Building default target step\n".cstring())
      return default_target_state_step_id
    end

    // Currently there are no splits (II), so we know that a node has
    // only one output in the graph.

    // Make sure this is not a sink or proxy node.
    match node.value
    | let eb: EgressBuilder val =>
      @printf[I32]("Sinks and Proxies have no output nodes in the local graph!\n".cstring())
      error
    end

    // Since this is not a sink or proxy, there should be exactly one
    // output.
    var out_id: U128 = 0
    for out in node.outs() do
      out_id = out.id
    end
    if out_id == 0 then
      @printf[I32]("Invariant was violated: non-sink node had no output node.\n".cstring())
      error
    end
    out_id

  // Connections knows how to plug proxies into other workers via TCP
  // fun _register_proxies(proxies: Map[String, Array[Step tag]]) =>
  //   for (worker, ps) in proxies.pairs() do
  //     for proxy in ps.values() do
  //       _connections.register_proxy(worker, proxy)
  //     end
  //   end
