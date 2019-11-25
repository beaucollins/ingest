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

  alias Simperium.RemoteChange

  ##
  # Message Structs
  ##

  defmodule BucketInit do
    @moduledoc """
    Sent by a `Simperium.Client` to start syncing a Simperium bucket.

    See [`init`](https://github.com/Simperium/simperium-protocol/blob/master/SYNCING.md#authorizing-init).
    """

    @enforce_keys [:clientid, :app_id, :name, :token]
    defstruct [
      # Represents a unique instance of a client.
      :clientid,
      # Simperium.com Application ID
      :app_id,
      # Bucket name
      :name,
      # Authorization token from simperium.com
      :token,
      # [Optional] command issued by simperium.com on successful init.
      :cmd,
      # The client library being used
      library: "simperium-ex",
      # The client's version
      version: "1.0.0",
      # Simperium.com API version to use
      api: 1
    ]
  end

  defmodule AuthenticationFailure do
    @moduledoc """
    After a `Simperium.Message.BucketInit` is sent, simperium.com [sends
    an `auth:*` response](https://github.com/Simperium/simperium-protocol/blob/master/SYNCING.md#authorization).

    Auth failures contain a JSON payload with a `msg` and `code` to communicate
    the failure reason.

        iex> "0:auth:{\\"msg\\":\\"Invalid token\\",\\"code\\":400}" |> parse()
        {:ok, {:bucket, 0, %Message.AuthenticationFailure{message: "Invalid token", code: 400}}}
    """
    defstruct [:message, :code]
  end

  defmodule AuthenticationSuccess do
    @moduledoc """
    After sending a successful `Simperium.Message.BucketInit` message Simperium replies
    with `0:auth:user@simperium.com`.

        iex> "0:auth:user@simperium.com" |> parse()
        {:ok, {:bucket, 0, %Message.AuthenticationSuccess{identity: "user@simperium.com"}}}
    """
    defstruct [:identity]
  end

  defmodule ChangeRequest do
    @moduledoc """
    Send a change for a bucket object.

        iex> Message.ChangeRequest.add_object("client-ex-1", "curent-cv", "unique-ccid", "object-key", %{"title" => %{ "o" => "+", "v" => "Hello"}})
        ...> |> encode()
        ~s(c:{"ccid":"unique-ccid","clientid":"client-ex-1","cv":"curent-cv","ev":1,"id":"object-key","o":"M"})
    """

    defstruct [:clientid, :cv, :ev, :sv, :id, :o, :v, :ccid, :d]

    @doc """
    Creates a change request that adds a new object with key `object_id` to a bucket.
    """
    def add_object(clientid, cv, ccid, object_id, object_diff) do
      %__MODULE__{
        clientid: clientid,
        cv: cv,
        ccid: ccid,
        id: object_id,
        v: object_diff,
        o: "M",
        ev: 1,
        sv: 0
      }
    end
  end

  defmodule RemoteChanges do
    @moduledoc """
    Simperium.com sends changes in realtime or when requested via a `Message.ChangeVersion`.

        iex> ~s(0:c:[{"clientid": "sjs-2012121301-9af05b4e9a95132f614c", "id": "newobject", "o": "M", "v": {"new": {"o": "+", "v": "object"}}, "ev": 1, "cv": "511aa58737a401031d57db90", "ccids": ["3a5cbd2f0a71fca4933fff5a54d22b60"]}])
        ...> |> parse()
        {:ok, {:bucket, 0, %Message.RemoteChanges{changes: [%Simperium.RemoteChange{
          clientid: "sjs-2012121301-9af05b4e9a95132f614c",
          cv: "511aa58737a401031d57db90",
          id: "newobject",
          o: "M",
          v: %{"new" => %{"o" => "+", "v" => "object"}},
          sv: nil,
          ev: 1,
          ccids: ["3a5cbd2f0a71fca4933fff5a54d22b60"]
        }]}}}
    """
    defstruct changes: []
  end

  defmodule Heartbeat do
    @moduledoc """
    `Simperium.Client` sends and rececives `Message.Heartbeat` messages to keep a connection
    alive.

    Receiving:

        iex> "h:100" |> parse()
        {:ok, {:connection, %Message.Heartbeat{count: 100}}}

    Sending:

        iex> %Message.Heartbeat{count: 101} |> encode()
        "h:101"
    """
    defstruct [:count]
  end

  defmodule IndexRequest do
    @moduledoc """
    Request the Bucket index. A bucket's index is the list of keys and versions known
    by the bucket. Can optionally include each bucket object's data.

        iex> %Message.IndexRequest{
        ...>   include_data?: true,
        ...>   limit: 200,
        ...> }
        ...> |> encode()
        "i:1:::200"
    """
    defstruct [:include_data?, :offset, :mark, :limit]
  end

  defmodule IndexPage do
    @moduledoc """
    Contains a page of the index. Sent by Simperium.com after a `Simperium.Message.IndexeRequest` is sent.

        iex> ~s(0:i:{"current": "5119dafb37a401031d47c0f7", "index": [{"id": "one", "v": 2}], "mark": "5119450b37a401031d3bfdb9"})
        ...> |> parse()
        {:ok, { :bucket, 0, %Message.IndexPage{
          current: "5119dafb37a401031d47c0f7",
          index: [%{"id" => "one", "v" => 2}],
          mark: "5119450b37a401031d3bfdb9"
        }}}
    )
    """
    defstruct [:current, :index, :mark]

    def from_map(map) when is_map(map) do
      %IndexPage{
        current: Map.get(map, "current"),
        index: Map.get(map, "index", []),
        mark: Map.get(map, "mark")
      }
    end
  end

  defmodule Log do
    @moduledoc """
    Simperium can send `log:*` messages to request clients to send extra
    information about the client's state back to teh Simperium.com service
    for debugging purpose.

        iex> "log:1" |> parse()
        {:ok, {:connection, %Message.Log{mode: 1}}}
    """
    defstruct [:mode]
  end

  defmodule UnknownObjectVersion do
    @moduledoc """
    Received when an object version is requested but Simperium does not
    know that object key at that version.

        iex> "0:e:keyname.1\\n?" |> parse()
        {:ok, {:bucket, 0, %Message.UnknownObjectVersion{
          key: "keyname",
          version: 1
        }}}

    """
    defstruct [:key, :version]
  end

  defmodule ObjectVersion do
    @moduledoc """
    Sent by a client to request a bucket object stored at `keyname` at
    a specific version.

        iex> %Message.ObjectVersion{key: "a-keyname", version: 1} |> encode()
        "e:a-keyname.1"

    If Simperium.com has the object at the requested version it replies with:

        iex> ~s(0:e:a-keyname.1\\n{"some":"data"}) |> parse()
        {:ok, {:bucket, 0, %Message.ObjectVersion{
          key: "a-keyname",
          version: 1,
          data: %{"some" => "data"}
        }}}

    If the bucket does not have the data for the key at that version it will send
    `Simperium.Message.UnknownObjectVersion` (`e:a-keyname.1\n?`)
    """
    defstruct [:key, :version, :data]
  end

  defmodule ChangeVersion do
    @moduledoc """
    Sent by a `Simperium.Client`.

    A `ChangeVersion` represents a the current version of the Bucket's state known by the client.

    To check if there are any new changes to by applied to te bucket, a client can send its
    current known `cv`.

        iex> %Message.ChangeVersion{cv: "abc"} |> encode()
        "cv:abc"

    `Simperium.Client` will prefix the proper channel number.

    If the `"cv:abc"` is unknown to Simperium.com, it will respond with `Simperium.Message.UnknownChangeVersion` (`"cv:?"`)
    """
    defstruct [:cv]
  end

  defmodule UnknownChangeVersion do
    @moduledoc """
    Sent by Simperium.com after receiving a `Simperium.Message.ChangeVersion` that is
    unknown to Simperium.com.

        iex> "0:cv:?" |> parse()
        {:ok, {:bucket, 0, %Message.UnknownChangeVersion{}}}
    """
    defstruct []
  end

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
                      {:ok, change} <- RemoteChange.from_json(change_data),
                      do: {:ok, changes ++ [change]}
               end),
             do: {:ok, %RemoteChanges{changes: changes}}

      {:error, _error} ->
        {:error, :invalid_remote_changes}
    end
  end

  defp parse_message_type("cv", "?") do
    {:ok, %UnknownChangeVersion{}}
  end

  defp parse_message_type("i", data) do
    case Jason.decode(data) do
      {:ok, page} -> {:ok, IndexPage.from_map(page)}
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
         %AuthenticationFailure{message: Map.get(failure, "msg"), code: Map.get(failure, "code")}}

      {:error, _} ->
        {:ok, %AuthenticationSuccess{identity: data}}
    end
  end

  defp parse_message_type("h", data) do
    case Integer.parse(data) do
      :error -> {:error, :invalid_heartbeat}
      {count, _rest} -> {:ok, %Heartbeat{count: count}}
    end
  end

  defp parse_message_type("log", data) do
    case Integer.parse(data) do
      :error -> {:error, :invalid_log_mode}
      {mode, _rest} -> {:ok, %Log{mode: mode}}
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
             do: {:ok, %UnknownObjectVersion{key: key, version: version}}

      [key_version, payload] ->
        with {:ok, {key, version}} <- parse_key_name_and_version(key_version),
             {:ok, decoded} <- Jason.decode(payload),
             do: {:ok, %ObjectVersion{key: key, version: version, data: decoded}}

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
