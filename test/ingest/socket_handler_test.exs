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

    assert text ===
             %{type: "action", action: %{nodes: Ingest.Monitor.Nodes.status(), type: "NODES"}}
             |> Jason.encode!()
  end

  describe "initialized" do
    setup do
      {:reply, _reply, state} = SocketHandler.websocket_init([])
      %{state: state}
    end

    test "websocket_info :subscriptions", %{state: state} do
      {:reply, reply, ^state} = SocketHandler.websocket_info({:subscriptions, []}, state)
      assert reply === {:text, %{subs: []} |> Jason.encode!()}
    end

    test "websocket_handle invalid payload", %{state: state} do
      {:reply, {:text, payload}, ^state} =
        SocketHandler.websocket_handle({:text, "not-json"}, state)

      assert %{
               "response" => %{"reason" => "invalid_encoding"},
               "type" => "result",
               "result" => "error"
             } = Jason.decode!(payload)
    end

    test "websocket_handle command lol", %{state: state} do
      {:reply, {:text, text}, ^state} =
        SocketHandler.websocket_handle({:text, "{\"command\":\"lol\"}"}, state)

      assert %{
               "response" => %{"command" => "lol", "reason" => "unknown_command"},
               "result" => "error"
             } = Jason.decode!(text)
    end

    test "websocket_handle command discover", %{state: state} do
      {:reply, {:text, text}, ^state} =
        SocketHandler.websocket_handle(
          {:text, "{\"command\":\"discover\", \"args\":[\"example.blog\"]}"},
          state
        )

      assert %{"response" => %{"tasks" => tasks}} = Jason.decode!(text)
    end
  end

  test "websocket_info", %{state: state} do
    {:ok, ^state} = SocketHandler.websocket_info(:mock, state)
  end

  test "websocket_info :nodeup", %{state: state} do
    {:reply, {:text, text}, ^state} = SocketHandler.websocket_info({:nodeup, :mock, :mock}, state)

    assert text ===
             %{type: "action", action: %{nodes: Ingest.Monitor.Nodes.status(), type: "NODES"}}
             |> Jason.encode!()
  end

  test "websocket_info :nodedown", %{state: state} do
    {:reply, {:text, text}, ^state} =
      SocketHandler.websocket_info({:nodedown, :mock, :mock}, state)

    assert text ===
             %{type: "action", action: %{type: "NODES", nodes: Ingest.Monitor.Nodes.status()}}
             |> Jason.encode!()
  end
end
