/*

Copyright (C) 2018
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
use "wallaroo/core/topology"

class PendingDataStore
  let _data_store: Map[String, Map[Key, Array[RoutingArguments]]] =
    _data_store.create()

  fun ref add(state_name: String, key: Key, routing_args: RoutingArguments) =>
    """
    Add a data item to the state_name/key array.
    """
    try
      _data_store.insert_if_absent(state_name, Map[Key, Array[RoutingArguments]])?.
        insert_if_absent(key, Array[RoutingArguments])?.push(routing_args)
    end

  fun ref retrieve(state_name: String, key: Key): Array[RoutingArguments] ? =>
    """
    Return the array of data items associated with the state_name/key and remove
    the key and items from the store.
    """
    (_, let v) = _data_store(state_name)?.remove(key)?
    v

  fun ref process_pending(producer: Producer ref, rerouter: Rerouter,
    router: (Router | DataRouter))
  =>
    for (state_name, keys_routing_args) in _data_store.pairs() do
      for (key, route_args) in keys_routing_args.pairs() do
        if router.routes_key(state_name, key) then
          for r in route_args.values() do
            r(rerouter, producer)
          end
        end
      end
    end
