class ProxyAddress
  let worker: String
  let step_id: U128

  new val create(w: String, s_id: U128) =>
    worker = w
    step_id = s_id

