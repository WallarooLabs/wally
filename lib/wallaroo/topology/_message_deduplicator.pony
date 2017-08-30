use "wallaroo/core"
use "wallaroo/fail"

// TODO: refactor to use everywhere
type MsgId is U128
type MsgIdAndFracs is (MsgId, FractionalMessageId)
type DeduplicationList is Array[MsgIdAndFracs]

primitive _MessageDeduplicator
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
            // unreachable
            Fail()
          end
          i = i + 1
        end

        return true
      end
    else
      return false
    end
    // unreachable
    Fail()
    false
