use "ponytest"
use "promises"


primitive TestCompleteOnPromises
  fun apply(h: TestHelper, ps: Array[Promise[None]]): Promise[Array[None] val]
  =>
    let p = Promises[None].join(ps.values())
    p.next[None]({(ns: Array[None] val) => h.complete(true)})
    p

