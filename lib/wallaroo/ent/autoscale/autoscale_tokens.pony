/*

Copyright 2018 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/ent/barrier"

class val AutoscaleTokens
  let worker: String
  let id: AutoscaleId
  let initial_token: AutoscaleBarrierToken
  let resume_token: AutoscaleResumeBarrierToken

  new val create(w: String, id': AutoscaleId) =>
    worker = w
    id = id'
    initial_token = AutoscaleBarrierToken(w, id)
    resume_token = AutoscaleResumeBarrierToken(w, id)
