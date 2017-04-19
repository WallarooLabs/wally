
class WMessage
  let sender: WActorId
  let receiver: WActorId
  let payload: Any val

  new val create(s: WActorId, r: WActorId, p: Any val) =>
    sender = s
    receiver = r
    payload = p
