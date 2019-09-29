defmodule Ingest.SubscriptionAgent do
  use Agent

  def start_link(_state) do
    Agent.start_link(&start_mnesia/0, name: __MODULE__)
  end

  def started? do
    Agent.get(__MODULE__, & &1)
  end

  defp start_mnesia do
    IO.puts("Starting Mnesia")
    with :ok <- :mnesia.create_schema([node()]),
         :ok <- :mnesia.start(),
         {:ok, nodes} <- :mnesia.change_config(:extra_db_nodes, Node.list),
         do: nodes
    |> IO.inspect(label: "Started")


    :ok
  end
end
