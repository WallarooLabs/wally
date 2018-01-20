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
use "options"
use "time"
use "wallaroo_labs/guid"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"

class DataGenSourceConfigCLIParser
  let _out: OutStream

  new create(out: OutStream) =>
    _out = out

  fun tag opts(): Array[(String, (None | String), ArgumentType, (Required |
    Optional), String)]
  =>
    // items in the tuple are: Argument Name, Argument Short Name,
    //   Argument Type, Required or Optional, Help Text
    let opts_array = Array[(String, (None | String), ArgumentType, (Required |
      Optional), String)]

    opts_array.push(("num_messages", None, I64Argument, Required,
      "number of messages to generate (1000000)"))
    opts_array.push(("message_size", None, I64Argument, Required,
      "size of messages to generate (1024)"))

    opts_array

  fun print_usage() =>
    for (long, short, arg_type, arg_req, help) in opts().values() do
      let short_str = match short
             | let s: String => "/-" + s
             else "" end

      let arg_type_str = match arg_type
             | StringArgument => "(String)"
             | I64Argument => "(Integer)"
             | F64Argument => "(Float)"
             else "" end

      _out.print("--" + long + short_str + "       " + arg_type_str + "    "
        + help)
    end


  fun parse_options(args: Array[String] val): (USize, USize) ?
  =>
    var num_msgs: USize = 1_000_000
    var msg_size: USize = 1_024

    let options = Options(args, false)

    for (long, short, arg_type, arg_req, _) in opts().values() do
      options.add(long, short, arg_type, arg_req)
    end

    // TODO: implement all the other options that kafka client supports
    for option in options do
      match option
      | ("num_messages", let input: I64) =>
        num_msgs = input.usize()
      | ("message_size", let input: I64) =>
        msg_size = input.usize()
      end
    end

    if msg_size < 0 then
      _out.print("Error! message_size (" + msg_size.string() + ") cannot be negative)!")
      error
    end

    if num_msgs < 0 then
      _out.print("Error! num_messages (" + num_msgs.string() + ") cannot be negative)!")
      error
    end

    (num_msgs, msg_size)

class val DataGenSourceConfig[In: Any val] is SourceConfig[In]
  let _handler: SourceHandler[In] val
  let _num_msgs: USize
  let _msg_size: USize

  new val create(num_msgs: USize, msg_size: USize,
    handler: SourceHandler[In] val)
  =>
    _handler = handler
    _num_msgs = num_msgs
    _msg_size = msg_size

  fun source_listener_builder_builder(): DataGenSourceListenerBuilderBuilder[In]
  =>
    DataGenSourceListenerBuilderBuilder[In](_num_msgs, _msg_size)

  fun source_builder(app_name: String, name: String):
    DataGenSourceBuilderBuilder[In]
  =>
    DataGenSourceBuilderBuilder[In](app_name, name, _handler)

class DataGenSourceListenerNotify[In: Any val]
  var _source_builder: SourceBuilder
  let _event_log: EventLog
  let _target_router: Router
  let _auth: AmbientAuth

  new iso create(builder: SourceBuilder, event_log: EventLog,
    auth: AmbientAuth, target_router: Router) =>
    _source_builder = builder
    _event_log = event_log
    _target_router = target_router
    _auth = auth

  fun ref build_source(env: Env): DataGenSourceNotify[In] iso^ ? =>
    try
      _source_builder(_event_log, _auth, _target_router, env) as
        DataGenSourceNotify[In] iso^
    else
      @printf[I32](
        (_source_builder.name()
          + " could not create a DataGenSourceNotify\n").cstring())
      Fail()
      error
    end

  fun ref update_router(router: Router) =>
    _source_builder = _source_builder.update_router(router)

class val DataGenSourceBuilderBuilder[In: Any val]
  let _handler: SourceHandler[In] val
  let _app_name: String
  let _name: String

  new val create(app_name: String, name': String,
    handler: SourceHandler[In] val)
  =>
    _app_name = app_name
    _name = name'
    _handler = handler

  fun name(): String => _name

  fun apply(runner_builder: RunnerBuilder, router: Router,
    metrics_conn: MetricsSink, pre_state_target_id: (U128 | None) = None,
    worker_name: String, metrics_reporter: MetricsReporter iso):
      SourceBuilder
  =>
    BasicSourceBuilder[In, SourceHandler[In] val](_app_name, worker_name,
      _name, runner_builder, _handler, router,
      metrics_conn, pre_state_target_id, consume metrics_reporter,
      DataGenSourceNotifyBuilder[In])

class val DataGenSourceListenerBuilderBuilder[In: Any val]
  let _num_msgs: USize
  let _msg_size: USize

  new val create(num_msgs: USize, msg_size: USize) =>
    _num_msgs = num_msgs
    _msg_size = msg_size

  fun apply(source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry, route_builder: RouteBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder | None) = None,
    target_router: Router = EmptyRouter): DataGenSourceListenerBuilder[In]
  =>
    DataGenSourceListenerBuilder[In](source_builder, router, router_registry,
      route_builder,
      outgoing_boundary_builders, event_log, auth,
      layout_initializer, consume metrics_reporter, default_target,
      default_in_route_builder, target_router, _num_msgs, _msg_size)

class val DataGenSourceListenerBuilder[In: Any val]
  let _source_builder: SourceBuilder
  let _router: Router
  let _router_registry: RouterRegistry
  let _route_builder: RouteBuilder
  let _default_in_route_builder: (RouteBuilder | None)
  let _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _layout_initializer: LayoutInitializer
  let _event_log: EventLog
  let _auth: AmbientAuth
  let _default_target: (Step | None)
  let _target_router: Router
  let _metrics_reporter: MetricsReporter
  let _num_msgs: USize
  let _msg_size: USize

  new val create(source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry, route_builder: RouteBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder | None) = None,
    target_router: Router = EmptyRouter,
    num_msgs: USize, msg_size: USize)
  =>
    _source_builder = source_builder
    _router = router
    _router_registry = router_registry
    _route_builder = route_builder
    _default_in_route_builder = default_in_route_builder
    _outgoing_boundary_builders = outgoing_boundary_builders
    _layout_initializer = layout_initializer
    _event_log = event_log
    _auth = auth
    _default_target = default_target
    _target_router = target_router
    _metrics_reporter = consume metrics_reporter
    _num_msgs = num_msgs
    _msg_size = msg_size

  fun apply(env: Env): SourceListener =>
    DataGenSourceListener[In](env, _source_builder, _router, _router_registry,
      _route_builder, _outgoing_boundary_builders,
      _event_log, _auth, _layout_initializer, _metrics_reporter.clone(),
      _default_target, _default_in_route_builder, _target_router, _num_msgs,
      _msg_size)

actor DataGenSourceListener[In: Any val] is (SourceListener)
  let _env: Env
  let _notify: DataGenSourceListenerNotify[In]
  let _router: Router
  let _router_registry: RouterRegistry
  let _route_builder: RouteBuilder
  let _default_in_route_builder: (RouteBuilder | None)
  var _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _layout_initializer: LayoutInitializer
  let _default_target: (Step | None)
  let _metrics_reporter: MetricsReporter
  let _num_msgs: USize
  let _msg_size: USize

  new create(env: Env, source_builder: SourceBuilder, router: Router,
    router_registry: RouterRegistry, route_builder: RouteBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    metrics_reporter: MetricsReporter iso,
    default_target: (Step | None) = None,
    default_in_route_builder: (RouteBuilder | None) = None,
    target_router: Router = EmptyRouter,
    num_msgs: USize, msg_size: USize)
  =>
    _env = env
    _notify = DataGenSourceListenerNotify[In](source_builder, event_log, auth,
      target_router)
    _router = router
    _router_registry = router_registry
    _route_builder = route_builder
    _default_in_route_builder = default_in_route_builder
    _outgoing_boundary_builders = outgoing_boundary_builders
    _layout_initializer = layout_initializer
    _default_target = default_target
    _metrics_reporter = consume metrics_reporter

    _num_msgs = num_msgs
    _msg_size = msg_size

    match router
    | let pr: PartitionRouter =>
      _router_registry.register_partition_router_subscriber(pr.state_name(),
        this)
    | let spr: StatelessPartitionRouter =>
      _router_registry.register_stateless_partition_router_subscriber(
        spr.partition_id(), this)
    end

    // create DataGenSource
    try
      let source = DataGenSource[In](this, _notify.build_source(_env)?,
        _router.routes(), _route_builder, _outgoing_boundary_builders,
        _layout_initializer, _default_target,
        _default_in_route_builder,
        _metrics_reporter.clone(), _num_msgs, _msg_size,
        _router_registry)
      _router_registry.register_source(source)
      match _router
      | let pr: PartitionRouter =>
        _router_registry.register_partition_router_subscriber(pr.state_name(), source)
      | let spr: StatelessPartitionRouter =>
        _router_registry.register_stateless_partition_router_subscriber(
          spr.partition_id(), source)
      end
    else
      Fail()
    end
 
  be update_router(router: Router) =>
    _notify.update_router(router)

  be remove_route_for(moving_step: Consumer) =>
    None

  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  =>
    let new_builders: Map[String, OutgoingBoundaryBuilder val] trn =
      recover Map[String, OutgoingBoundaryBuilder val] end
    // TODO: A persistent map on the field would be much more efficient here
    for (target_worker_name, builder) in _outgoing_boundary_builders.pairs() do
      if not new_builders.contains(target_worker_name) then
        new_builders(target_worker_name) = builder
      end
    end
    _outgoing_boundary_builders = consume new_builders

  be dispose() =>
    None

primitive DataGenSourceNotifyBuilder[In: Any val]
  fun apply(pipeline_name: String, env: Env, auth: AmbientAuth,
    handler: SourceHandler[In] val,
    runner_builder: RunnerBuilder, router: Router,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router, pre_state_target_id: (U128 | None) = None):
    SourceNotify iso^
  =>
    DataGenSourceNotify[In](pipeline_name, env, auth, handler, runner_builder,
      router, consume metrics_reporter, event_log, target_router,
      pre_state_target_id)

class DataGenSourceNotify[In: Any val]
  let _env: Env
  let _msg_id_gen: MsgIdGenerator = MsgIdGenerator
  let _pipeline_name: String
  let _source_name: String
  let _handler: SourceHandler[In] val
  let _runner: Runner
  var _router: Router
  let _omni_router: OmniRouter = EmptyOmniRouter
  let _metrics_reporter: MetricsReporter

  new iso create(pipeline_name: String, env: Env, auth: AmbientAuth,
    handler: SourceHandler[In] val,
    runner_builder: RunnerBuilder, router: Router,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router, pre_state_target_id: (U128 | None) = None)
  =>
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"
    _env = env
    _handler = handler
    _runner = runner_builder(event_log, auth, None,
      target_router, pre_state_target_id)
    _router = _runner.clone_router_and_set_input_type(router)
    _metrics_reporter = consume metrics_reporter

  fun routes(): Array[Consumer] val =>
    _router.routes()

  fun ref received(src: DataGenSource[In] ref, data: Array[U8] val)
  =>
    _metrics_reporter.pipeline_ingest(_pipeline_name, _source_name)
    let ingest_ts = Time.nanos()
    let pipeline_time_spent: U64 = 0
    var latest_metrics_id: U16 = 1

    ifdef "trace" then
      @printf[I32](("Generated msg at " + _pipeline_name + " source\n").cstring())
    end

    (let is_finished, let keep_sending, let last_ts) =
      try
        src.next_sequence_id()
        let decoded =
          try
            _handler.decode(consume data)?
          else
            ifdef debug then
              @printf[I32]("Error decoding message at source\n".cstring())
            end
            error
          end
        let decode_end_ts = Time.nanos()
        _metrics_reporter.step_metric(_pipeline_name,
          "Decode Time in Kafka Source", latest_metrics_id, ingest_ts,
          decode_end_ts)
        latest_metrics_id = latest_metrics_id + 1

        ifdef "trace" then
          @printf[I32](("Msg decoded at " + _pipeline_name +
            " source\n").cstring())
        end
        _runner.run[In](_pipeline_name, pipeline_time_spent, decoded,
          src, _router, _omni_router, _msg_id_gen(), None,
          decode_end_ts, latest_metrics_id, ingest_ts, _metrics_reporter)
      else
        @printf[I32](("Unable to decode message at " + _pipeline_name +
          " source\n").cstring())
        ifdef debug then
          Fail()
        end
        (true, true, ingest_ts)
      end

    if is_finished then
      let end_ts = Time.nanos()
      let time_spent = end_ts - ingest_ts

      ifdef "detailed-metrics" then
        _metrics_reporter.step_metric(_pipeline_name,
          "Before end at DataGen Source", 9999,
          last_ts, end_ts)
      end

      _metrics_reporter.pipeline_metric(_pipeline_name, time_spent +
        pipeline_time_spent)
      _metrics_reporter.worker_metric(_pipeline_name, time_spent)
    end

  fun ref update_router(router: Router) =>
    _router = router

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    match _router
    | let p_router: PartitionRouter =>
      _router = p_router.update_boundaries(obs)
    else
      ifdef "trace" then
        @printf[I32](("DataGenSourceNotify doesn't have PartitionRouter. " +
          "Updating boundaries is a noop for this kind of Source.\n").cstring())
      end
    end

actor DataGenSource[In: Any val] is (Producer)
  let _step_id_gen: StepIdGenerator = StepIdGenerator
  let _routes: MapIs[Consumer, Route] = _routes.create()
  let _route_builder: RouteBuilder
  let _outgoing_boundaries: Map[String, OutgoingBoundary] =
    _outgoing_boundaries.create()
  let _layout_initializer: LayoutInitializer
  var _unregistered: Bool = false

  let _metrics_reporter: MetricsReporter

  let _listen: DataGenSourceListener[In]
  let _notify: DataGenSourceNotify[In]

  var _muted: Bool = true
  let _muted_downstream: SetIs[Any tag] = _muted_downstream.create()

  let _router_registry: RouterRegistry

  // Producer (Resilience)
  var _seq_id: SeqId = 1 // 0 is reserved for "not seen yet"

  let _num_msgs: USize
  var _num_msgs_generated: USize = 0
  let _msg_size: USize

  new create(listen: DataGenSourceListener[In],
    notify: DataGenSourceNotify[In] iso,
    routes: Array[Consumer] val, route_builder: RouteBuilder,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    layout_initializer: LayoutInitializer,
    default_target: (Consumer | None) = None,
    forward_route_builder: (RouteBuilder | None) = None,
    metrics_reporter: MetricsReporter iso,
    num_msgs: USize, msg_size: USize,
    router_registry: RouterRegistry)
  =>
    _num_msgs = num_msgs
    _msg_size = msg_size

    ifdef debug then
      @printf[I32](("Generating " + _num_msgs.string() + " messages of size: " + _msg_size.string() + ".\n").cstring())
    end

    _metrics_reporter = consume metrics_reporter
    _listen = listen
    _notify = consume notify

    _layout_initializer = layout_initializer
    _router_registry = router_registry

    _route_builder = route_builder
    for (target_worker_name, builder) in outgoing_boundary_builders.pairs() do
      let new_boundary =
        builder.build_and_initialize(_step_id_gen(), _layout_initializer)
      router_registry.register_disposable(new_boundary)
      _outgoing_boundaries(target_worker_name) = new_boundary
    end

    for consumer in routes.values() do
      _routes(consumer) =
        _route_builder(this, consumer, _metrics_reporter)
    end

    for (worker, boundary) in _outgoing_boundaries.pairs() do
      _routes(boundary) =
        _route_builder(this, boundary, _metrics_reporter)
    end

    _notify.update_boundaries(_outgoing_boundaries)

    match default_target
    | let r: Consumer =>
      match forward_route_builder
      | let frb: RouteBuilder =>
        _routes(r) = frb(this, r, _metrics_reporter)
      end
    end

    for r in _routes.values() do
      // TODO: this is a hack, we shouldn't be calling application events
      // directly. route lifecycle needs to be broken out better from
      // application lifecycle
      r.application_created()
    end

    for r in _routes.values() do
      r.application_initialized("DataGenSource")
    end

    _mute()

  be update_router(router: Router) =>
    let new_router =
      match router
      | let pr: PartitionRouter =>
        pr.update_boundaries(_outgoing_boundaries)
      | let spr: StatelessPartitionRouter =>
        spr.update_boundaries(_outgoing_boundaries)
      else
        router
      end
    _notify.update_router(new_router)

  be add_boundary_builders(
    boundary_builders: Map[String, OutgoingBoundaryBuilder] val)
  =>
    """
    Build a new boundary for each builder that corresponds to a worker we
    don't yet have a boundary to. Each DataGenSource has its own
    OutgoingBoundary to each worker to allow for higher throughput.
    """
    for (target_worker_name, builder) in boundary_builders.pairs() do
      if not _outgoing_boundaries.contains(target_worker_name) then
        let boundary = builder.build_and_initialize(_step_id_gen(),
          _layout_initializer)
        _outgoing_boundaries(target_worker_name) = boundary
        _router_registry.register_disposable(boundary)
        _routes(boundary) =
          _route_builder(this, boundary, _metrics_reporter)
      end
    end
    _notify.update_boundaries(_outgoing_boundaries)

  be reconnect_boundary(target_worker_name: String) =>
    try
      _outgoing_boundaries(target_worker_name)?.reconnect()
    else
      Fail()
    end

  be remove_route_for(step: Consumer) =>
    try
      _routes.remove(step)?
    else
      Fail()
    end

  //////////////
  // ORIGIN (resilience)
  be request_ack() =>
    None

  fun ref _acker(): Acker =>
    // TODO: we don't really need this
    // Because we dont actually do any resilience work
    Acker

  // Override these for DataGenSource as we are currently
  // not resilient.
  fun ref flush(low_watermark: U64) =>
    None

  be log_flushed(low_watermark: SeqId) =>
    None

  fun ref bookkeeping(o_route_id: RouteId, o_seq_id: SeqId) =>
    None

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    ifdef debug then
      @printf[I32]("DataGenSource received update_watermark\n".cstring())
    end

  fun ref _update_watermark(route_id: RouteId, seq_id: SeqId) =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    try
      _routes(c)?
    else
      None
    end

  fun ref next_sequence_id(): SeqId =>
    _seq_id = _seq_id + 1

  fun ref current_sequence_id(): SeqId =>
    _seq_id

  // generate data function
  be generate_data() =>
    if _muted then
      ifdef debug then
        @printf[I32](("Stopping generating data because muted. Generated so far: " + _num_msgs_generated.string() + "\n").cstring())
      end
      return
    end

    if _num_msgs_generated < _num_msgs then

      let data = recover val
          Array[U8].>undefined(_msg_size)
        end

      _notify.received(this, consume data)

      _num_msgs_generated = _num_msgs_generated + 1

      // generate more data
      generate_data()
    else
      ifdef debug then
        @printf[I32](("Finished generating all " + _num_msgs_generated.string() + " messages.\n").cstring())
      end
    end

  fun ref _mute() =>
    ifdef debug then
      @printf[I32]("Muting DataGenSource\n".cstring())
    end

    _muted = true

  fun ref _unmute() =>
    ifdef debug then
      @printf[I32]("Unmuting DataGenSource\n".cstring())
    end

    generate_data()

    _muted = false

  be mute(c: Consumer) =>
    _muted_downstream.set(c)
    _mute()

  be unmute(c: Consumer) =>
    _muted_downstream.unset(c)

    if _muted_downstream.size() == 0 then
      _unmute()
    end

  fun ref is_muted(): Bool =>
    _muted

  be dispose() =>
    @printf[I32]("Shutting down DataGenSource\n".cstring())

    for b in _outgoing_boundaries.values() do
      b.dispose()
    end
