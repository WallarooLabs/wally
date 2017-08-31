use "wallaroo/core"

class val ProxyAddress
  let worker: String
  let step_id: StepId

  new val create(w: String, s_id: StepId) =>
    worker = w
    step_id = s_id

  fun string(): String =>
    "[[" + worker + ": " + step_id.string() + "]]"

  fun eq(that: box->ProxyAddress): Bool =>
    (worker == that.worker) and (step_id == that.step_id)

  fun ne(that: box->ProxyAddress): Bool => not eq(that)
