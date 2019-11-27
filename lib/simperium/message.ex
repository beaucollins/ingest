defmodule Simperium.Message do
  @moduledoc """
  Simperium's [protocol messages](https://github.com/Simperium/simperium-protocol/blob/master/SYNCING.md#streaming-api).

  These messages map to the incoming and outgoing messages a Simperium realtime
  syncing client uses when communicationg to the simperium.com syncing service.

  Incoming messages are parsed with `Simperium.Message.parse/1`:

      iex> "h:100" |> Simperium.Message.parse()
      {:ok, {:connection, %Message.Heartbeat{count: 100}}}

  A single connection to Simperium multiplexes bucket syncing for `n` buckets. `parse/1`
  handles this by returning `{:connection, message}` for connection related messages or
  `{bucket, channel, message}` for a specific bucket .

  Simperium's `log:*` message:

      iex> "log:1" |> Message.parse()
      {:ok, {:connection, %Message.Log{mode: 1}}}

  Simperium's `*:auth:user@example.com` message:

      iex> "100:auth:user@example.com" |> Message.parse()
      {:ok, {:bucket, 100, %Message.AuthenticationSuccess{identity: "user@example.com"}}}

  Outgoing messages are encoded by implementing `Simperium.Message.Encoder`.

      iex> %Message.Heartbeat{count: 87} |> Message.encode()
      "h:87"
  """

  alias Simperium.Message
  alias Simperium.Change

  @doc """
  Encodes outgoing messages to Simperium.

      iex> %Message.Heartbeat{count: 100} |> encode()
      "h:100"

  Messages define how they are encoded by implementing `Simperium.Message.Encoder`.
  """
  def encode(message) do
    Simperium.MessageEncoder.encode(message)
  end

  @doc """
  Turn binary data into an incoming Simperium.Message.

  Messages prefixed with an integer are for specific buckets:

      iex> parse("234:c:[]")
      {:ok, {:bucket, 234, %Message.RemoteChanges{}}}

  Messages without an integer prefix are for the entire connection:

      iex> parse("h:123")
      {:ok, {:connection, %Message.Heartbeat{count: 123}}}

  """
  def parse(<<data::binary>> = _binary) do
    with :error <- parse_bucket_message(data),
         do: parse_connection_message(data)
  end

  defp parse_channel(data) do
    case Integer.parse(data) do
      :error -> :error
      {channel, rest} -> {:ok, channel, String.split(rest, ":", trim: true, parts: 2)}
    end
  end

  defp parse_bucket_message(data) do
    with {:ok, channel, [message_type, data]} <- parse_channel(data),
         {:ok, message} <- parse_message_type(message_type, data),
         do: {:ok, {:bucket, channel, message}}
  end

  defp parse_connection_message(data) do
    case String.split(data, ":", parts: 2) do
      [message_type, data] ->
        with {:ok, message} <- parse_message_type(message_type, data),
             do: {:ok, {:connection, message}}

      _ ->
        {:error, :invalid_message_type}
    end
  end

  defp parse_message_type("c", data) do
    case Jason.decode(data) do
      {:ok, changes} when is_list(changes) ->
        with {:ok, changes} <-
               Enum.reduce(changes, {:ok, []}, fn change_data, result ->
                 with {:ok, changes} <- result,
                      {:ok, change} <- Change.from_json(change_data),
                      do: {:ok, changes ++ [change]}
               end),
             do: {:ok, %Message.RemoteChanges{changes: changes}}

      {:error, _error} ->
        {:error, :invalid_remote_changes}
    end
  end

  defp parse_message_type("cv", "?") do
    {:ok, %Message.UnknownChangeVersion{}}
  end

  defp parse_message_type("i", data) do
    case Jason.decode(data) do
      {:ok, page} -> {:ok, Message.IndexPage.from_map(page)}
      {:error, _} -> {:error, :invalid_page}
    end
  end

  # ignore the auth:expired message
  # it has beeen supersceded by auth:{} with JSON encoded error
  defp parse_message_type("auth", "expired") do
    {:ok, :noop}
  end

  defp parse_message_type("auth", data) do
    case Jason.decode(data) do
      {:ok, failure} ->
        {:ok,
         %Message.AuthenticationFailure{
           message: Map.get(failure, "msg"),
           code: Map.get(failure, "code")
         }}

      {:error, _} ->
        {:ok, %Message.AuthenticationSuccess{identity: data}}
    end
  end

  defp parse_message_type("h", data) do
    case Integer.parse(data) do
      :error -> {:error, :invalid_heartbeat}
      {count, _rest} -> {:ok, %Message.Heartbeat{count: count}}
    end
  end

  defp parse_message_type("log", data) do
    case Integer.parse(data) do
      :error -> {:error, :invalid_log_mode}
      {mode, _rest} -> {:ok, %Message.Log{mode: mode}}
    end
  end

  # e:keyname.1\n?
  # e:keyname.1\n{}
  defp parse_message_type("e", data) do
    parse_key_version(data)
  end

  defp parse_message_type(_type, _data) do
    {:error, :unknown_message_type}
  end

  # keyname.1\n
  defp parse_key_version(data) do
    case String.split(data, "\n", parts: 2) do
      [key_version, "?"] ->
        with {:ok, {key, version}} <- parse_key_name_and_version(key_version),
             do: {:ok, %Message.UnknownObjectVersion{key: key, version: version}}

      [key_version, payload] ->
        with {:ok, {key, version}} <- parse_key_name_and_version(key_version),
             {:ok, decoded} <- Jason.decode(payload),
             do: {:ok, %Message.ObjectVersion{key: key, version: version, data: decoded}}

      _ ->
        {:error, :invalid_entity_key}
    end
  end

  # keyname.1
  defp parse_key_name_and_version(key_version) do
    result =
      case(String.split(key_version, ".")) do
        key_path when length(key_path) < 2 ->
          {:error, :invalid_key_version}

        key_path ->
          {:ok, {Enum.join(Enum.slice(key_path, 0..-2), "."), List.last(key_path)}}
      end

    result =
      with {:ok, {key, version_string}} <- result,
           {version, _rest} <- Integer.parse(version_string),
           do: {:ok, {key, version}}

    case result do
      :error -> {:error, :invalid_key_version}
      _ -> result
    end
  end
end
