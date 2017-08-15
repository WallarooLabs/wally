class WMessage
  let sender: U128
  let receiver: U128
  let payload: Any val

  new val create(s: U128, r: U128, p: Any val) =>
    sender = s
    receiver = r
    payload = p
