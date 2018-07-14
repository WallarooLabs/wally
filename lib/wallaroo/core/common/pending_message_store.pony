/*

Copyright 2018 The Wallaroo Authors.

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
use "wallaroo/core/routing"
use "wallaroo/core/topology"

class PendingMessageStore
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

  fun ref process_known_keys(producer: Producer ref, rerouter: Rerouter,
    router: (Router | DataRouter))
  =>
    for (state_name, keys_routing_args) in _data_store.pairs() do
      for (key, route_args) in keys_routing_args.pairs() do
        if router.has_state_partition(state_name, key) then
          try
            keys_routing_args.remove(key)?
            for r in route_args.values() do
              r(rerouter, producer)
            end
          end
        end
      end
    end
