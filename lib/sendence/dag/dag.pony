use "collections"
use "../guid"

class Dag[V: Any val]
  let _guid_gen: GuidGenerator = GuidGenerator
  let _nodes: Map[U128, DagNode[V]] = _nodes.create()
  let _edges: Array[(DagNode[V], DagNode[V])] = _edges.create()

  fun ref add_node(value: V, id': U128 = 0): U128 =>
    let id = if id' == 0 then _guid_gen.u128() else id' end 
    _nodes(id) = DagNode[V](value, id)
    id

  fun get_node(id: U128): this->DagNode[V] ? =>
    _nodes(id)

  fun nodes(): Iterator[this->DagNode[V]] =>
    _nodes.values()

  fun edges(): Iterator[(this->DagNode[V], this->DagNode[V])] =>
    _edges.values()

  fun ref add_edge(from_id: U128, to_id: U128) ? =>
    let from = _nodes(from_id)
    let to = _nodes(to_id)
    if from.has_input_from(to) then
      @printf[I32]("Cycles are not allowed!\n".cstring())
      error
    end
    if not from.has_output_from(to) then
      _edges.push((from, to))
      from.add_output(to)      
      to.add_input(from)      
    end    

  fun is_empty(): Bool => _nodes.size() == 0

  fun clone(): Dag[V] val ? =>
    let c: Dag[V] trn = recover Dag[V] end 
    for (id, node) in _nodes.pairs() do
      c.add_node(node.value, node.id)
    end
    for edge in _edges.values() do
      c.add_edge(edge._1.id, edge._2.id)
    end 
    consume c

  fun string(): String =>
    var s = ""
    for (id, node) in _nodes.pairs() do
      s = s + id.u16().string() + " | "
      var outputs = ""
      for out in node.outs() do
        outputs = outputs + out.id.u16().string() + "  "
      end
      s = s + outputs + "\n"
    end
    s

class DagNode[V: Any val]
  let id: U128
  let _ins: Array[DagNode[V]] = _ins.create()
  let _outs: Array[DagNode[V]] = _outs.create()
  let value: V

  new create(v: V, id': U128) =>
    value = v
    id = id'

  fun ref add_input(input: DagNode[V]) =>
    if not _ins.contains(input) then
      _ins.push(input)
    end

  fun ref add_output(output: DagNode[V]) =>
    if not _outs.contains(output) then
      _outs.push(output)
    end

  fun has_input_from(node: DagNode[V]): Bool =>
    _ins.contains(node)
  fun has_output_from(node: DagNode[V]): Bool =>
    _outs.contains(node)

  fun ins(): Iterator[this->DagNode[V]] => _ins.values()
  fun outs(): Iterator[this->DagNode[V]] => _outs.values()

  fun is_source(): Bool => _ins.size() == 0
  fun is_sink(): Bool => _outs.size() == 0

