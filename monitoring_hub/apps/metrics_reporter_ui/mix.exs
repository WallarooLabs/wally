defmodule MetricsReporterUI.Mixfile do
  use Mix.Project

  def project do
    [app: :metrics_reporter_ui,
     version: "0.0.1",
     build_path: "_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.0",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {MetricsReporterUI, []},
     applications: [:phoenix, :phoenix_html, :cowboy, :logger, :gettext, :gproc,
      :phoenix_tcp, :metrics_reporter, :monitoring_hub_utils]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:phoenix, "~> 1.3.0"},
     {:phoenix_html, "~> 2.10.5"},
     {:phoenix_live_reload, "~> 1.1.3", only: :dev},
     {:gettext, "~> 0.14.0"},
     {:cowboy, "~> 1.0"},
     {:distillery, "~> 1.5.2"},
     {:phoenix_tcp, git: "https://github.com/WallarooLabs/phoenix_tcp.git", branch: "update-deps"},
     {:monitoring_hub_utils, in_umbrella: true},
     {:metrics_reporter, in_umbrella: true}]
  end
end
