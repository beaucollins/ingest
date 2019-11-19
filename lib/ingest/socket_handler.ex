defmodule Ingest.SocketHandler do
  @moduledoc """
  Represents a single websocket request for a single user of the system implementing `:cowboy_websocket`.
  """
  @behaviour :cowboy_websocket

  @doc """
  Websocket request is being initialized. Return state associated with the socket. Opportune
  time to implement Authentication.

  Callback implementation for `:cowboy_websocket.init/2`
  """
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

  def websocket_handle({:text, data}, state) do
    response =
      with {:ok, [command: command, args: args]} <- parse_command(data),
           do: run_command(command, args)

    reply_command(response, state)
  end

  def websocket_info(info, state) do
    case info do
      {:nodeup, _node, _type} ->
        reply_nodes(state)

      {:nodedown, _node, _type} ->
        reply_nodes(state)

      {:subscriptions, _subs} ->
        reply_subscriptions(state)

      {:discover, uuid, urls, feeds} ->
        reply_discover(uuid, urls, feeds, state)

      _ ->
        {:ok, state}
    end
  end

  defp reply_subscriptions([subs: subs] = state) do
    {:reply, {:text, %{subs: Ingest.SubscriptionAgent.list(subs)} |> Jason.encode!()}, state}
  end

  defp reply_nodes(state) do
    {:reply,
     {:text,
      %{type: "action", action: %{type: "NODES", nodes: Ingest.Monitor.Nodes.status()}}
      |> Jason.encode!()}, state}
  end

  defp reply_command(result, state) do
    case result do
      {:reply, response} ->
        {:reply,
         {:text, Jason.encode!(%{"type" => "result", "result" => "ok", "response" => response})},
         state}

      :ok ->
        {:ok, state}

      {:error, reason} ->
        {:reply,
         {:text, Jason.encode!(%{"type" => "result", "result" => "error", "response" => reason})},
         state}

      _ ->
        {:ok, state}
    end
  end

  defp parse_command(data) do
    case Jason.decode(data) do
      {:ok, %{"command" => command, "args" => args}} when is_binary(command) and is_list(args) ->
        {:ok, [command: command, args: args]}

      {:ok, %{"command" => command}} when is_binary(command) ->
        {:ok, [command: command, args: []]}

      {:error, _reason} ->
        {:error, %{"reason" => :invalid_encoding}}

      _ ->
        {:error, %{"reason" => :invalid_parameters}}
    end
  end

  defp run_command(_command, _args \\ [])

  defp run_command("discover", urls) do
    pid = self()

    tasks =
      Enum.map(urls, fn url ->
        uuid = UUID.uuid4()

        {uuid,
         Task.async(fn ->
           feeds = Ingest.Discovery.find_feed(url)
           send(pid, {:discover, uuid, url, feeds})
         end)}
      end)

    {:reply,
     %{
       "tasks" => Enum.map(tasks, fn {uuid, task} -> uuid end)
     }}
  end

  defp run_command(command, _args) do
    {:error, %{"reason" => :unknown_command, "command" => command}}
  end

  defp reply_discover(uuid, urls, feeds, state) do
    {:reply,
     {:text,
      Jason.encode!(%{
        "task" => uuid,
        "urls" => urls,
        "feeds" => Tuple.to_list(feeds)
      })}, state}
  end
end
