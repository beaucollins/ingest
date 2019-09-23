defmodule Ingest.SocketHandler do
  @behaviour :cowboy_websocket

  def init(request, state) do
    IO.inspect(state, label: "Incoming websocket")
    IO.inspect(self(), label: "Init <==")
    {:cowboy_websocket, request, state}
  end

  def websocket_init(state) do
    IO.inspect(self(), label: "Websocket Processs")
    IO.inspect(state)

    case :net_kernel.monitor_nodes(true, [{:node_type, :all}]) do
      :ok ->
        reply_nodes(state)

      _ ->
        {:stop, state}
    end
  end

  def websocket_handle(frame, state) do
    IO.inspect(frame, label: "Frame <==")
    IO.inspect(self(), label: "websocket frame")
    {:ok, state}
  end

  def websocket_info(info, state) do
    IO.inspect({self(), info}, label: "Info <==")
    case info do
      {:nodeup, _node, _type} ->
        reply_nodes(state)

      {:nodedown, _node, _type} ->
        reply_nodes(state)

        _ -> {:ok, state}
    end
  end

  def terminate(state, handler_state, reason) do
    IO.inspect(state)
    IO.inspect(handler_state)
    IO.inspect(reason, label: "terminated:")
    IO.inspect(self(), label: "terminated PID:")
  end

  defp nodes do
    {Node.self(), Node.list([:this, :connected])}
  end

  defp reply_nodes(state) do
    {:reply, {:text, nodes() |> Tuple.to_list |> Jason.encode! }, state}
  end
end
