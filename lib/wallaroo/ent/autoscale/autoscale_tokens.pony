


class val AutoscaleTokens
  let worker: String
  let id: AutoscaleId
  let initial_token: AutoscaleBarrierToken
  let resume_token: AutoscaleResumeBarrierToken

  new val create(w: String, id: AutoscaleId) =>
    worker = w
    id = id
    initial_token = AutoscaleBarrierToken(w, id)
    resume_token = AutoscaleResumeBarrierToken(w, id)
