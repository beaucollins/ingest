defmodule Ingest.Net do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl true
  def init(_) do
    case Node.start(Node.self()) do
      {:ok, pid} ->
        IO.puts("Started node")
        {:ok, {pid, %{}}}

      {:error, reason} ->
        IO.puts("Failed to start node #{Node.self()}:")
        IO.inspect(reason)
        {:ok, {nil, %{}}}
    end
  end
end
