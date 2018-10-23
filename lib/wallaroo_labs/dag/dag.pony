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
use "../guid"

class Dag[V: Any val]
  let _nodes: Map[U128, DagNode[V]] = _nodes.create()
  let _edges: Array[(DagNode[V], DagNode[V])] = _edges.create()
  let _sinks: SetIs[DagNode[V]] = _sinks.create()

  fun ref add_node(value: V, id': U128 = 0): U128 =>
    let id = if id' == 0 then _gen_guid() else id' end
    let node = DagNode[V](value, id)
    _nodes(id) = node
    _sinks.set(node)
    id

  fun contains(id: U128): Bool =>
    _nodes.contains(id)

  fun get_node(id: U128): this->DagNode[V] ? =>
    _nodes(id)?

  fun nodes(): Iterator[this->DagNode[V]] =>
    _nodes.values()

  fun edges(): Iterator[(this->DagNode[V], this->DagNode[V])] =>
    _edges.values()

  fun ref add_edge(from_id: U128, to_id: U128) ? =>
    try
      let from =
        try
          _nodes(from_id)?
        else
          @printf[I32]("There is no node for from_id %s\n".cstring(),
            from_id.string().cstring())
          error
        end
      let to =
        try
          _nodes(to_id)?
        else
          @printf[I32]("There is no node for to_id %s\n".cstring(),
            to_id.string().cstring())
          error
        end

      // Obviously this only catches simple cycles
      if from.has_input_from(to) then
        @printf[I32]("Cycles are not allowed!\n".cstring())
        error
      end
      if not from.has_output_from(to) then
        _edges.push((from, to))
        from.add_output(to)
        to.add_input(from)
        if _sinks.contains(from) then
          _sinks.unset(from)
        end
      end
    else
      @printf[I32]("Failed to add edge to graph\n".cstring())
      error
    end

  fun ref merge(dag: Dag[V]) ? =>
    for (n_id, n) in dag._nodes.pairs() do
      if _nodes.contains(n_id) then
        @printf[I32]("Can't merge Dag with duplicate node id\n".cstring())
        error
      end
      add_node(n.value, n_id)
    end
    for (from, to) in dag._edges.values() do
      add_edge(from.id, to.id)?
    end

  fun without_sources(): Dag[V] val ? =>
    let new_dag = recover iso Dag[V] end
    let removed = SetIs[U128]

    for n in _nodes.values() do
      if n.is_source() then
        removed.set(n.id)
      else
        new_dag.add_node(n.value, n.id)
      end
    end
    for e in _edges.values() do
      (let from, let to) = e
      if not (removed.contains(from.id) or removed.contains(to.id)) then
        new_dag.add_edge(from.id, to.id)?
      end
    end
    consume new_dag

  fun sinks(): Iterator[this->DagNode[V]] =>
    _sinks.values()

  fun is_empty(): Bool => _nodes.size() == 0

  fun size(): USize => _nodes.size()

  fun clone(): Dag[V] val ? =>
    let c = recover trn Dag[V] end
    for (id, node) in _nodes.pairs() do
      c.add_node(node.value, node.id)
    end
    for edge in _edges.values() do
      c.add_edge(edge._1.id, edge._2.id)?
    end
    consume c

  fun string(): String =>
    var s = "GRAPH:\n"
    for (id, node) in _nodes.pairs() do
      let name =
        match node.value
        | let n: Named val => "\"" + n.name() + "\""
        else
          id.u16().string()
        end

      s = s + name + " --> "
      var outputs = ""
      for out in node.outs() do
        let out_name =
          match out.value
          | let n: Named val => "\"" + n.name() + "\""
          else
            id.u16().string()
          end

        outputs = outputs + out_name + "  "
      end
      if outputs == "" then outputs = "<>" end
      s = s + outputs + "\n\n"
    end
    s

  // Apparently Random can't be serialized, so we can't hold a GuidGenerator
  // as a field
  fun _gen_guid(): U128 =>
    GuidGenerator.u128()

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

interface Named
  fun name(): String
