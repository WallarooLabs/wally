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
use "ponytest"
use "wallaroo_labs/equality"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/data_receiver"
use "wallaroo/core/network"
use "wallaroo/core/recovery"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    _TestRouterEquality.make().tests(test)
    _TestStepSeqIdGenerator.make().tests(test)
