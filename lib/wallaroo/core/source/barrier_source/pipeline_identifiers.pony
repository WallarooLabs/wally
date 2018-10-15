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
use "wallaroo/core/topology"


primitive _PipelineIdentifierCreator
  fun apply(router: Router): _PipelineIdentifier =>
    match router
    | let pr: StatePartitionRouter =>
      _PartitionRouterPId(pr)
    | let spr: StatelessPartitionRouter =>
      _StatelessPartitionRouterPId(spr)
    else
      _UnchangingRouterPId(router)
    end

trait val _PipelineIdentifier is (Hashable & Equatable[_PipelineIdentifier])

class val _UnchangingRouterPId is _PipelineIdentifier
  let _router: Router

  new val create(r: Router) =>
    _router = r

  fun eq(that: box->_PipelineIdentifier): Bool =>
    match that
    | let ir: _UnchangingRouterPId =>
      _router == ir._router
    else
      false
    end

  fun hash(): USize =>
    _router.hash()

class val _PartitionRouterPId is _PipelineIdentifier
  let _router: StatePartitionRouter

  new val create(pr: StatePartitionRouter) =>
    _router = pr

  fun eq(that: box->_PipelineIdentifier): Bool =>
    match that
    | let ir: _PartitionRouterPId =>
      _router.state_name() == ir._router.state_name()
    else
      false
    end

  fun hash(): USize =>
    _router.hash()

class val _StatelessPartitionRouterPId is _PipelineIdentifier
  let _router: StatelessPartitionRouter

  new val create(spr: StatelessPartitionRouter) =>
    _router = spr

  fun eq(that: box->_PipelineIdentifier): Bool =>
    match that
    | let ir: _StatelessPartitionRouterPId =>
      _router.partition_routing_id() == ir._router.partition_routing_id()
    else
      false
    end

  fun hash(): USize =>
    _router.hash()
