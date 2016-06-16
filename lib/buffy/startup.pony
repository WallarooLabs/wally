use "options"
use "./topology"
use "./sink-node"

actor Startup
  // TODO: factor out source_count
  new create(env: Env, topology: Topology val, source_count: USize,
    sink_step_builders: Array[SinkNodeStepBuilder val] val =
    recover Array[SinkNodeStepBuilder val] end)
  =>
    let options = Options(env)
    var node_type: NodeType = BuffyNode

    options
      .add("run-sink", "", None)

    for option in options do
      match option
      | ("run-sink", None) => node_type = SinkNode
      end
    end

    match node_type
    | BuffyNode => StartupBuffyNode(env, topology, source_count)
    | SinkNode => StartupSinkNode(env, sink_step_builders)
    end

type NodeType is (BuffyNode | SinkNode)
primitive BuffyNode
primitive SinkNode
