primitive EventTypes
  fun sinks(): String => "source-sink-metrics"
  fun boundaries(): String => "ingress-egress-metrics"
  fun steps(): String => "step-metrics"

actor MonitoringHubOutput
  let env: Env
  let app_name: String

  new create(env': Env, app_name': String) =>
    env = env'
    app_name = app_name'

  fun send(category: String, payload: String) =>
    env.out.print(consume payload)

  be send_sinks(payload: String) =>
    send("sinks", payload)

  be send_boundaries(payload: String) =>
    send("boundaries", payload)

  be send_steps(payload: String) =>
    send("steps", payload)
