defmodule Ingest.MixProject do
  use Mix.Project

  def project do
    [
      app: :ingest,
      version: "0.3.4",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Docs
      name: "Ingest",
      source_url: "https://gitlab.com/coplusco/ingest",
      docs: [
        main: "Ingest",
        extras: [
          "README.md",
          "docs/hello.md"
        ],
        source_ref: "simperium"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Ingest.Application, [env: Mix.env()]},
      extra_applications: [:logger, :runtime_tools],
      included_applications: [:mnesia]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:httpoison, "~> 1.6.1"},
      {:mochiweb, "~> 2.18.0"},
      {:plug_cowboy, "~> 2.0"},
      {:jason, "~> 1.1"},
      {:feedraptor, "~> 0.3.0"},
      {:phoenix, "~> 1.4.11"},
      {:phoenix_html, "~> 2.13.3"},
      {:libcluster, "~>3.2.0"},
      {:websockex, "~> 0.4.2"},
      {:elixir_uuid, "~> 1.2"},
      {:ex_doc, "~>0.21", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    []
  end
end
