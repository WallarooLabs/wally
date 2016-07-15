use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :market_spread_reports_ui, MarketSpreadReportsUI.Endpoint,
  http: [port: 4001],
  tcp: [port: 5555],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [npm: ["run", "watch"]]

# Watch static and templates for browser reloading.
config :market_spread_reports_ui, MarketSpreadReportsUI.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{web/views/.*(ex)$},
      ~r{web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development.
# Do not configure such in production as keeping
# and calculating stacktraces is usually expensive.
config :phoenix, :stacktrace_depth, 20
