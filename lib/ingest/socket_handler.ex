defmodule Ingest.SocketHandler do
  @behaviour :cowboy_websocket

  def init(request, state) do
    {:cowboy_websocket, request, state}
  end

  def websocket_init(state) do
    status =
      with :ok <- :net_kernel.monitor_nodes(true, [{:node_type, :all}]),
           {:ok, subs} <- Ingest.SubscriptionAgent.start_link(),
           do: {:ok, Keyword.put(state, :subs, subs)}

    case status do
      {:ok, state} ->
        reply_nodes(state)

      _ ->
        {:stop, state}
    end
  end

  def websocket_handle(_frame, state) do
    {:ok, state}
  end

  def websocket_info(info, state) do
    case info do
      {:nodeup, _node, _type} ->
        reply_nodes(state)

      {:nodedown, _node, _type} ->
        reply_nodes(state)

      _ ->
        {:ok, state}
    end
  end

  defp reply_nodes(state) do
    {:reply, {:text, Ingest.Monitor.Nodes.status() |> Jason.encode!()}, state}
  end
end
