defmodule Ingest.SocketHandlerTest do
  use ExUnit.Case

  alias Ingest.SocketHandler

  setup do
    {:cowboy_websocket, :mock, state} = SocketHandler.init(:mock, [])
    %{state: state}
  end

  test "websocket_init", %{state: state} do
    {:reply, {:text, text}, [subs: subs]} = SocketHandler.websocket_init(state)

    assert is_pid(subs)
    assert text === Ingest.Monitor.Nodes.status() |> Jason.encode!()
  end

  test "websocket_info", %{state: state} do
    {:ok, ^state} = SocketHandler.websocket_info(:mock, state)
  end

  test "websocket_info :nodeup", %{state: state} do
    {:reply, {:text, text}, ^state} = SocketHandler.websocket_info({:nodeup, :mock, :mock}, state)
    assert text === Ingest.Monitor.Nodes.status() |> Jason.encode!()
  end

  test "websocket_info :nodedown", %{state: state} do
    {:reply, {:text, text}, ^state} =
      SocketHandler.websocket_info({:nodedown, :mock, :mock}, state)

    assert text === Ingest.Monitor.Nodes.status() |> Jason.encode!()
  end
end
