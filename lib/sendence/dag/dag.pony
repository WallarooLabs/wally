use "collections"
use "../guid"

class Dag[V: Any #alias]
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
    if from.ins.contains(to) then
      @printf[I32]("Cycles are not allowed!\n".cstring())
      error
    end
    if not from.outs.contains(to) then
      _edges.push((from, to))
      from.add_output(to)      
      to.add_input(from)      
    end    

class DagNode[V: Any #alias]
  let id: U128
  let ins: Array[DagNode[V]] = ins.create()
  let outs: Array[DagNode[V]] = outs.create()
  let value: V

  new create(v: V, id': U128) =>
    value = v
    id = id'

  fun ref add_input(input: DagNode[V]) =>
    if not ins.contains(input) then
      ins.push(input)
    end

  fun ref add_output(output: DagNode[V]) =>
    if not outs.contains(output) then
      outs.push(output)
    end
