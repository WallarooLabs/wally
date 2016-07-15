# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the namespace used by Phoenix generators
config :metrics_reporter_ui,
  app_namespace: MetricsReporterUI

# Configures the endpoint
config :metrics_reporter_ui, MetricsReporterUI.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "7Rd6tfZQ+ZiBINWy2Vh0s6ngSafn5/NNmPtPoqSchWWsCbkbBR1jCjJLfPxdm5m2",
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: MetricsReporterUI.PubSub,
           adapter: Phoenix.PubSub.PG2],
  tcp_handler: PhoenixTCP.RanchHandler

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
