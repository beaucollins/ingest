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
      with {:ok, [command: command, uuid: uuid, args: args]} <- parse_command(data),
           do: run_command(command, uuid, args)

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

      {:discover, uuid, url, feeds} ->
        reply_discover(uuid, url, feeds, state)

      {:fetchfeed, uuid, feeds} ->
        reply_fetchfeed(uuid, feeds, state)

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
      {:reply, uuid, response} ->
        {:reply,
         {:text,
          Jason.encode!(%{
            "type" => "result",
            "uuid" => uuid,
            "result" => "ok",
            "response" => response
          })}, state}

      {:ok, uuid} ->
        {:reply, {:text, Jason.encode!(%{"type" => "ack", "uuid" => uuid})}, state}

      {:error, uuid, reason} ->
        {:reply,
         {:text,
          Jason.encode!(%{
            "type" => "result",
            "uuid" => uuid,
            "result" => "error",
            "response" => reason
          })}, state}

      _ ->
        {:ok, state}
    end
  end

  defp parse_command(data) do
    case Jason.decode(data) do
      {:ok, %{"command" => command, "uuid" => uuid, "args" => args}}
      when is_binary(command) ->
        {:ok, [command: command, uuid: uuid, args: args]}

      {:ok, %{"command" => command, "args" => args}} when is_binary(command) and is_list(args) ->
        {:ok, [command: command, uuid: UUID.uuid4(), args: args]}

      {:ok, %{"command" => command, "uuid" => uuid}} when is_binary(command) ->
        {:ok, [command: command, uuid: uuid, args: []]}

      {:ok, %{"command" => command}} when is_binary(command) ->
        {:ok, [command: command, uuid: UUID.uuid4(), args: []]}

      {:error, _reason} ->
        {:error, UUID.uuid4(), %{"reason" => :invalid_encoding}}

      _ ->
        {:error, UUID.uuid4(), %{"reason" => :invalid_parameters}}
    end
  end

  defp run_command(command, uuid, args)

  defp run_command("discover", uuid, urls) do
    pid = self()

    tasks =
      Enum.map(urls, fn url ->
        Task.async(fn ->
          feeds = Ingest.Discovery.find_feed(url)
          send(pid, {:discover, uuid, url, feeds})
        end)
      end)

    {:reply, uuid,
     %{
       "tasks" => Enum.map(tasks, fn task -> inspect(task.pid) end)
     }}
  end

  defp run_command("fetchfeed", uuid, feed) do
    pid = self()
    result = with {:ok, url} <- Map.fetch(feed, "url"),
        {:ok, host} <- Map.fetch(feed, "host"),
        do: {:ok, Task.async(fn ->
              send(pid, {:fetchfeed, uuid, URI.merge(host, url) |> Ingest.fetch})
            end)}

    case result do
      {:ok, task} ->
        {:reply, uuid, %{ "task" => inspect(task)}}
      :error ->
        {:error, uuid, %{"reason" => :invalid_command, "uuid" => uuid}}
    end
  end

  defp run_command(command, uuid, _args) do
    {:error, uuid, %{"reason" => :unknown_command, "uuid" => uuid, "command" => command}}
  end

  defp reply_discover(uuid, url, feeds, state) do
    {:reply,
     {:text,
      Jason.encode!(%{
        "type" => "action",
        "action" => %{
          "type" => "DISCOVER",
          "uuid" => uuid,
          "url" => url,
          "feeds" => Tuple.to_list(feeds)
        }
      })}, state}
  end

  defp reply_fetchfeed(uuid, feed, state) do
    {:reply,
     {:text,
      Jason.encode!(%{
        "type" => "action",
        "action" => %{
          "type" => "FETCH_FEED_RESULT",
          "uuid" => uuid,
          "feed" => Tuple.to_list(feed)
        }
      })}, state}
  end
end
