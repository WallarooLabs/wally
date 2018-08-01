

use "wallaroo/ent/barrier"


class val LogRotationBarrierToken is BarrierToken
  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let lbt: LogRotationBarrierToken =>
      true
    else
      false
    end

  fun hash(): USize =>
    0

  fun lt(that: box->BarrierToken): Bool =>
    false

  fun string(): String =>
    "LogRotationBarrierToken"

class val LogRotationResumeBarrierToken is BarrierToken
  fun eq(that: box->BarrierToken): Bool =>
    match that
    | let lbt: LogRotationResumeBarrierToken =>
      true
    else
      false
    end

  fun hash(): USize =>
    0

  fun lt(that: box->BarrierToken): Bool =>
    false

  fun string(): String =>
    "LogRotationResumeBarrierToken"
