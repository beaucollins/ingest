defmodule Simperium.Connection do
  @moduledoc """
  A single IO connection to simperium.com that understands how to
  multiplex messages.
  """
  use WebSockex
  alias Simperium.MessageEncoder

  @spec send_bucket_message(
          atom | pid | {:global, any} | {:via, atom, any},
          number,
          Simperium.MessageEncoder.t()
        ) :: :ok
  @doc """
  Send a message to simperium.com real-time service to a specific bucket channel.
  """
  def send_bucket_message(connection, bucket_channel, message) do
    WebSockex.cast(connection, {:bucket, bucket_channel, message})
  end

  @spec send_connection_message(
          atom | pid | {:global, any} | {:via, atom, any},
          Simperium.MessageEncoder.t()
        ) :: :ok
  @doc """
  Send a message to simperium.com for the entire connection.
  """
  def send_connection_message(connection, message) do
    WebSockex.cast(connection, {:connection, message})
  end

  @doc """
  Start a connection to Simperium.com's realtime syncing service.
  """
  def start_link(state, opts \\ []) do
    # chalk-bump-f49
    url = "wss://api.simperium.com/sock/1/#{state.app_id}/websocket"

    WebSockex.start_link(url, __MODULE__, state, opts |> Keyword.merge(async: true))
  end

  @impl true
  def handle_connect(_conn, state) do
    # TODO: send auth message
    # Existing buckets need to re-authenticate
    # {:ok, state}
    # {:reply, {:text, "0:init:{}"}, state}
    {:ok, state}
  end

  @impl true
  def handle_frame({:text, text}, %{app_id: app_id} = state) do
    case Simperium.Message.parse(text) do
      {:ok, {:connection, message}} ->
        debug(message, label: "<=*  ")

        Registry.dispatch(state.registry, :connection, fn entries ->
          Enum.each(entries, fn
            {pid, ^app_id} ->
              send(pid, {:simperium, :connection, message})

            _ ->
              :noop
          end)
        end)

      {:ok, {:bucket, channel, message}} ->
        debug(message, label: "<=#{channel}")

        Registry.dispatch(state.registry, :bucket, fn entries ->
          Enum.each(entries, fn
            {pid, ^app_id} ->
              send(pid, {:simperium, :bucket, channel, message})

            {pid, %Simperium.Bucket.Channel{app_id: ^app_id, channel: ^channel}} ->
              send(pid, {:simperium, :bucket, message})

            _ ->
              :noop
          end)
        end)

      {:error, reason} ->
        IO.inspect(reason, label: " <?> ")
    end

    {:ok, state}
  end

  def handle_frame(_frame, state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:heartbeat, count}, state) when is_number(count) do
    {:reply, {:text, "h:#{count}"}, state}
  end

  @impl true
  def handle_cast({:bucket, channel, message}, state) do
    encoded =
      message
      |> debug(label: "  (#{inspect(channel)})=>")
      |> MessageEncoder.encode()
      |> IO.inspect(label: "  =>")

    {:reply, {:text, to_string(channel) <> ":" <> encoded}, state}
  end

  @impl true
  def handle_cast({:connection, message}, state) do
    encoded =
      message
      |> debug(label: "  *=>")
      |> MessageEncoder.encode()

    {:reply, {:text, encoded}, state}
  end

  @impl true
  def handle_cast(msg, state) do
    IO.puts("Handle cast #{inspect(msg)}")
    {:ok, state}
  end

  defp debug(message, opts \\ []) do
    message
    |> Simperium.MessageDebug.debug()
    |> IO.inspect(opts)

    message
  end
end
