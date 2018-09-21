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

use "wallaroo_labs/mort"
use "wallaroo/core/common"

type DeduplicationList is Array[MsgIdAndFracs]

primitive MessageDeduplicator
  fun is_duplicate(msg_uid: MsgId, frac_ids: FractionalMessageId,
    list: DeduplicationList): Bool
  =>
    for e in list.values() do
      // if we don't match on a given list item, keep searching
      if _individual_match(e, (msg_uid, frac_ids)) then
        return true
      end
    end
    false

  fun _individual_match(check: MsgIdAndFracs, against: MsgIdAndFracs):
    Bool
  =>
    if check._1 == against._1 then
      match (check._2, against._2)
      | (None, None) =>
        return true
      | (let x: Array[U32] val, None) =>
        return false
      | (None, let x: Array[U32] val) =>
        return false
      | (let x: Array[U32] val, let y: Array[U32] val) =>
        if x.size() != y.size() then
          return false
        end

        var i = USize(0)
        while (i < x.size()) do
          try
            if x(i)? != y(i)? then
              return false
            end
          else
            Unreachable()
          end
          i = i + 1
        end

        return true
      end
    else
      return false
    end
    Unreachable()
    false
