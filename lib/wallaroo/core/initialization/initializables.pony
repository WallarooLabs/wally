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
use "wallaroo/core/common"
use "wallaroo/core/boundary"
use "wallaroo_labs/mort"


class Initializables
  var _reporting: Bool = false
  let _initializables: SetIs[Initializable] = _initializables.create()

  fun size(): USize =>
    _initializables.size()

  fun contains(i: Initializable): Bool =>
    _initializables.contains(i)

  fun ref remove_boundaries() =>
    let boundaries = Array[OutgoingBoundary]
    for i in _initializables.values() do
      match i
      | let ob: OutgoingBoundary =>
        boundaries.push(ob)
      end
    end
    for b in boundaries.values() do
      _initializables.unset(b)
    end

  fun ref set(i: Initializable) =>
    if not _reporting then
      _initializables.set(i)
    else
      Fail()
    end

  fun ref unset(i: Initializable) =>
    _initializables.unset(i)

  fun ref application_begin_reporting(initializer: LocalTopologyInitializer) =>
    for i in _initializables.values() do
      i.application_begin_reporting(initializer)
    end

  fun ref application_created(initializer: LocalTopologyInitializer) =>
    for i in _initializables.values() do
      i.application_created(initializer)
    end

  fun ref application_initialized(initializer: LocalTopologyInitializer) =>
    for i in _initializables.values() do
      i.application_initialized(initializer)
    end

  fun ref application_ready_to_work(initializer: LocalTopologyInitializer) =>
    for i in _initializables.values() do
      i.application_ready_to_work(initializer)
    end

  fun ref cluster_ready_to_work(initializer: LocalTopologyInitializer) =>
    for i in _initializables.values() do
      i.cluster_ready_to_work(initializer)
    end
