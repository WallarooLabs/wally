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

use "wallaroo/core/barrier"
use "wallaroo/core/common"

class val AutoscaleTokens
  let worker: String
  let id: AutoscaleId
  let initial_token: AutoscaleBarrierToken
  let resume_token: AutoscaleResumeBarrierToken

  new val create(w: String, id': AutoscaleId, lws: Array[WorkerName] val) =>
    worker = w
    id = id'
    initial_token = AutoscaleBarrierToken(w, id, lws)
    resume_token = AutoscaleResumeBarrierToken(w, id)
