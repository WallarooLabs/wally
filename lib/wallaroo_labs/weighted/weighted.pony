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

primitive Weighted[V: Any val]
  fun apply(unsorted_items: Array[(V, USize)] val, bucket_count: USize):
    Array[Array[V]] val ?
  =>
    try
      recover
        let items = sort(unsorted_items)
        let buckets: Array[Array[V]] = buckets.create()
        let bucket_weights: Array[USize] = bucket_weights.create()
        for i in Range(0, bucket_count) do
          buckets.push(recover Array[V] end)
          bucket_weights.push(0)
        end

        // Keep adding the next highest weighted item to the bucket with
        // the lowest weight
        while items.size() > 0 do
          let next_bucket_idx = _lowest_weight_idx(bucket_weights)
          let next_item = items.pop()
          buckets(next_bucket_idx).push(next_item._1)
          let new_bucket_weight_total =
            bucket_weights(next_bucket_idx) + next_item._2
          bucket_weights(next_bucket_idx) = new_bucket_weight_total
        end
        consume buckets
      end
    else
      @printf[I32]("Bucket count must be at least 1 and there must be at least one item to place in buckets\n".cstring())
      error
    end


  // This assumes bucket_weights has a size greater than 0, ensured by the
  // initial bucket_count check in apply
  fun _lowest_weight_idx(bucket_weights: Array[USize]): USize ? =>
    try
      var idx: USize = 0
      var lowest_weight: USize = bucket_weights(0)
      for i in Range(0, bucket_weights.size()) do
        if bucket_weights(i) < lowest_weight then
          idx = i
          lowest_weight = bucket_weights(i)
        end
      end
      idx
    else
      @printf[I32]("Failed at _lowest_weight_idx\n".cstring())
      error
    end

  // TODO: Replace with builtin Pony sort
  // This only happens once, so I'm taking the lazy but slow route for now
  // just to get this working
  fun sort(a: Array[(V, USize)] val): Array[(V, USize)] ? =>
    try
      let sorted: Array[(V, USize)] = sorted.create()
      let to_sort: Array[(V, USize)] = to_sort.create()
      for item in a.values() do
        to_sort.push(item)
      end

      while to_sort.size() > 0 do
        let next_idx = _lowest_sort_idx(to_sort)
        sorted.push(to_sort.delete(next_idx))
      end
      sorted
    else
      @printf[I32]("Failed at sort\n".cstring())
      error
    end

  fun _lowest_sort_idx(a: Array[(V, USize)]): USize ? =>
    try
      var idx: USize = 0
      var lowest_weight: USize = a(0)._2
      for i in Range(0, a.size()) do
        let next_weight = a(i)._2
        if next_weight < lowest_weight then
          idx = i
          lowest_weight = next_weight
        end
      end
      idx
    else
      @printf[I32]("Failed at _lowest_sort_idx\n".cstring())
      error
    end
