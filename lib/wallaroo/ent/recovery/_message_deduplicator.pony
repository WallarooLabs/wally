/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "sendence/mort"
use "wallaroo/core"

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
            if x(i) != y(i) then
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
