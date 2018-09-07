/*

Copyright 2018 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/core/common"

class val BoundaryEdge is Equatable[BoundaryEdge]
  let input_id: RoutingId
  let output_id: RoutingId

  new val create(i: RoutingId, o: RoutingId) =>
    input_id = i
    output_id = o

  fun eq(that: box->BoundaryEdge): Bool =>
    (input_id == that.input_id) and (output_id == that.output_id)

  fun hash(): USize =>
    input_id.hash() xor output_id.hash()

