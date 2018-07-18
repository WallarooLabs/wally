/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/core/source"


trait val _Pending


class val _PendingBarrier is _Pending
  let token: BarrierToken
  let promise: BarrierResultPromise

  new val create(t: BarrierToken, p: BarrierResultPromise) =>
    token = t
    promise = p

class val _PendingSourceInit is _Pending
  let source: Source

  new val create(s: Source) =>
    source = s
