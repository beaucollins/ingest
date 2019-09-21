defmodule Ingest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Ingest.Worker.start_link(arg)
      # {Ingest.Worker, arg},
      {Plug.Cowboy, scheme: :http, plug: Ingest.Service},
      Ingest.Net
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ingest.Supervisor]

    Supervisor.start_link(
      case args do
        [env: :test] ->
          children ++ [{Plug.Cowboy, scheme: :http, plug: Ingest.Proxy, options: [port: 5431]}]

        [_] ->
          children
      end,
      opts
    )
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(_changed, _new, _removed) do
    :ok
  end
end
