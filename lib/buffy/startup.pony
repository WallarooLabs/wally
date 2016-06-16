use "options"
use "./topology"
use "./sink-node"

actor Startup
  // TODO: factor out source_count
  new create(env: Env, topology: Topology val, source_count: USize, 
    sink_step_builders: Array[SinkNodeStepBuilder val] val = 
      recover Array[SinkNodeStepBuilder val] end) =>
    let options = Options(env)
    var is_sink = false

    options
      .add("run-sink", "", None)

    for option in options do
      match option
      | ("run-sink", None) => is_sink = true
      end
    end

    if is_sink then
      StartupSinkNode(env, sink_step_builders)
    else
      StartupBuffyNode(env, topology, source_count)
    end
