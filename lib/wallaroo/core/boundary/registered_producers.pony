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
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"


class RegisteredProducers
  // map from producer id to a set of target ids
  let _targets: Map[RoutingId, SetIs[RoutingId]] = _targets.create()
  // map from producer id to producer
  let _producers: Map[RoutingId, Producer] = _producers.create()

  fun size(): USize =>
    var count: USize = 0
    for target_ids in _targets.values() do
      for _ in target_ids.values() do
        count = count + 1
      end
    end
    count

  fun ref register_producer(producer_id: RoutingId, producer: Producer,
    target_id: RoutingId)
  =>
    _producers(producer_id) = producer
    try
      _targets.insert_if_absent(producer_id, SetIs[RoutingId])?.set(target_id)
    else
      Unreachable()
    end

  fun ref unregister_producer(producer_id: RoutingId, producer: Producer,
    target_id: RoutingId)
  =>
    if _targets.contains(producer_id) then
      try
        let target_ids = _targets(producer_id)?
        target_ids.unset(target_id)
        if target_ids.size() == 0 then
          try
            _producers.remove(producer_id)?
          else
            ifdef debug then
              @printf[I32]("Attempted to remove unknown producer %s\n"
                .cstring(), producer_id.string().cstring())
            end
          end
        end
      else
        Unreachable()
      end
    end

  fun ref registrations(): Array[(RoutingId, Producer, RoutingId)] =>
    """
    Return triples of form (producer_id, producer, target_id)
    """
    let regs = Array[(RoutingId, Producer, RoutingId)]
    for (producer_id, target_ids) in _targets.pairs() do
      for target_id in target_ids.values() do
        try
          let producer = _producers(producer_id)?
          regs.push((producer_id, producer, target_id))
        else
          Fail()
        end
      end
    end
    regs

  fun ref clear() =>
    _targets.clear()
    _producers.clear()
