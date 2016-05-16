use "collections"
use "net"
use "buffy/messages"
use "sendence/bytes"

primitive EventTypes
  fun sinks(): String => "source-sink-metrics"
  fun boundaries(): String => "ingress-egress-metrics"
  fun steps(): String => "step-metrics"

actor MonitoringHubOutput
  let _env: Env
  let _app_name: String
  let _conn: TCPConnection

  new create(env: Env, app_name: String, output: MonitoringHubActor) =>
    _env = env
    _app_name = app_name

  be send(category: String, payload: String) =>
    _env.out.print(consume payload)

  be send_sinks(payload: String) =>
    send(EventTypes.sinks(), payload)

  be send_boundaries(payload: String) =>
    send(EventTypes.boundaries(), payload)

  be send_steps(payload: String) =>
    send(EventTypes.steps(), payload)
