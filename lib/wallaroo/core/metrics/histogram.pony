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

class Histogram
  """
  A Histogram where each value is counted into the bin of its next power of 2
  value. e.g. 3->bin:4, 4->bin:4, 5->bin:8, etc.

  In addition to the histogram itself, we are storing the min, max_value
  and total number of values seen (throughput) for reporting.
  """
  embed _counts: Array[U64] ref = Array[U64].init(0, 65)
  var _min: U64 = U64.max_value()
  var _max: U64 = U64.min_value()

  fun get_idx(v: U64): USize =>
    """
    Return the power of 2 of the value to be used as its index in the histogram
    """
    64 - v.clz().usize()

  fun get(i: USize): U64 ? =>
    """
    Get the count at the i-th bin, raising an error if the index is out
    of bounds.
    """
    _counts(i)?

  fun size(): U64 =>
    var s = U64(0)
    for i in _counts.values() do
      s = s + i
    end
    s

  fun counts(): this->Array[U64] ref => _counts

  fun min(): U64 => _min

  fun max(): U64 => _max

  fun ref apply(v: U64) =>
  """
  Count a U64 value in the correct bin in the histogram
  """
    let idx = get_idx(v)
    try
      _counts(idx)? =  _counts(idx)? + 1
      if v < _min then _min = v end
      if v > _max then _max = v end
    end
