/*

Copyright (C) 2016-2017, Wallaroo Labs
Copyright (C) 2016-2017, The Pony Developers
Copyright (c) 2014-2015, Causality Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
            Fail()
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
