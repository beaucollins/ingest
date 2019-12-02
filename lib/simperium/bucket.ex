defmodule Simperium.Bucket do
  use GenServer

  alias Simperium.Change
  alias Simperium.ChangeError
  alias Simperium.Ghost
  alias Simperium.Message

  @moduledoc """
  `GenServer` implementation that performs Simperium realtime syncing.

  See `Simperium.Client.create_bucket/3`.

      iex> {:ok, client} = Simperium.Client.start_link()
      ...> {ok, bucket} = Simperium.Client.create_bucket(client, "notes", "supersecure");

  """

  defmodule Channel do
    defstruct [:app_id, :auth_token, :channel, :bucket_name]
  end

  #
  # Client
  #

  @doc """
  The current Simperium `cv` for this Bucket.
  """
  def cv(bucket) do
    GenServer.call(bucket, :cv)
  end

  @doc """
  Retrieves the current known object in the Bucket for the given key.
  """
  def get(bucket, id) do
    case GenServer.call(bucket, {:get, id}) do
      nil -> nil
      %Simperium.Ghost{value: value} -> value
    end
  end

  def put(bucket, id, value) do
    GenServer.call(bucket, {:put, id, value})
  end

  def has_complete_index?(bucket) do
    GenServer.call(bucket, :index_complete?)
  end

  def request_changes(bucket) do
    GenServer.call(bucket, :request_changes)
  end

  def reindex(bucket) do
    GenServer.call(bucket, :reindex)
  end

  @doc """
  Given a `Simperium.Bucket`s state, returns the init command that should be used when
  connecting to Simperium's real-time sync service.
  """
  def create_init_command(bucket) do
    GenServer.call(bucket, :init_command)
  end

  def apply_command(bucket, command) do
    GenServer.call(bucket, {:apply_command, command})
  end

  def start_link(init_arg, opts \\ []) do
    GenServer.start_link(__MODULE__, init_arg, opts)
  end

  # @spec start_link(map, keyword) :: :ignore | {:error, any} | {:ok, pid}
  # def start_link(state, opts) when is_map(state) do
  #   registry = Keyword.fetch!(opts, :registry)
  #   channel = Keyword.fetch!(opts, :channel)

  #   GenServer.start_link(
  #     __MODULE__,
  #     default_state()
  #     |> Map.merge(state)
  #     |> Map.merge(%{registry: registry, channel: channel}),
  #     opts |> Keyword.drop([:registry, :channel])
  #   )
  # end

  #
  # Server
  #
  @impl true
  def init(registry: registry, channel: channel, state: state) do
    Registry.register(registry, :bucket, channel)

    {:ok,
     %{
       registry: registry,
       channel: channel,
       bucket: Map.merge(default_state(), state)
     }}
  end

  def init(registry: registry, channel: channel) do
    Registry.register(registry, :bucket, channel)

    {:ok,
     %{
       registry: registry,
       channel: channel,
       bucket: default_state()
     }}
  end

  @impl true
  def init(_init_arg) do
    {:stop, :invalid_init_arg}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    {:reply, Map.get(state.bucket.ghosts, id), state}
  end

  @impl true
  def handle_call(:cv, _from, state) do
    {:reply, state.bucket.cv, state}
  end

  @impl true
  def handle_call(:init_command, _from, %{bucket: %{cv: :new, index_complete?: true}} = state) do
    # no cv, but index is completed? No message needs to be sent
    {:reply, :noop, state}
  end

  @impl true
  def handle_call(:init_command, _from, %{bucket: %{cv: cv, index_complete?: true}} = state) do
    {:reply, %Message.ChangeVersion{cv: cv}, state}
  end

  @impl true
  def handle_call(:init_command, _from, state) do
    {:reply, initial_index_request(), state}
  end

  @impl true
  def handle_call(
        {:apply_command, _command = %Message.RemoteChanges{}},
        _from,
        %{bucket: %{index_complete?: false}} = state
      ) do
    {:reply, {:error, :noindex}, state}
  end

  @impl true
  def handle_call(:index_complete?, _from, %{bucket: %{index_complete?: index_complete?}} = state) do
    {:reply, index_complete?, state}
  end

  def handle_call(:request_changes, _from, %{bucket: %{index_complete?: false}} = state) do
    {:reply, {:error, :no_index}, state}
  end

  @impl true
  def handle_call(:request_changes, _form, %{bucket: %{cv: cv}} = state) do
    broadcast_message(%Message.ChangeVersion{cv: cv}, state)
    {:reply, cv, state}
  end

  @impl true
  def handle_call(:reindex, _from, state) do
    broadcast_message(initial_index_request(), state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:apply_command, command}, _from, state) do
    case handle_command(command, state) do
      {:ok, result, state} -> {:reply, {:ok, result}, state}
    end
  end

  def handle_call({:put, id, value}, _from, state) do
    # build the Change and seind
    # TODO pending changes, network changes
    {operation, source} =
      case Map.get(state.bucket.ghosts, id) do
        nil ->
          {"+", Simperium.Ghost.create_version(0, %{})}

        ghost = %Simperium.Ghost{} ->
          {"M", ghost}
      end

    case Simperium.JSONDiff.create_diff(source.value, value) do
      {:ok, diff} ->
        change_request = %Simperium.Message.ChangeRequest{
          clientid: "the-missile-knows-where-it-is",
          cv: state.bucket.cv,
          ccid: UUID.uuid4(),
          id: id,
          o: operation,
          v: diff,
          sv: source.version
        }

        broadcast_message(change_request, state)

        {:reply, {:ok, change_request}, state}

      error = {:error, _} ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:simperium, :bucket, command}, state) do
    case handle_command(command, state) do
      {:ok, _reply, state} -> {:noreply, state}
      {:ok, state} -> {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp handle_command(command = %Simperium.Message.RemoteChanges{}, state) do
    case command.changes |> Enum.reduce({:ok, [], state.bucket}, &reduce_changes/2) do
      {:ok, updates, bucket} -> {:ok, updates, %{state | bucket: bucket}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_command(command = %Message.IndexPage{}, state) do
    ghosts =
      Enum.reduce(
        command.index,
        state.bucket.ghosts,
        fn %{"d" => data, "id" => id, "v" => version}, ghosts ->
          Map.put(ghosts, id, Ghost.create_version(version, data))
        end
      )

    complete =
      case Message.IndexRequest.next_page(command) do
        nil ->
          %{index_complete?: true, cv: command.current}

        request ->
          broadcast_message(request, state)
          %{index_complete?: false, cv: command.current}
      end

    {
      :ok,
      %{state | bucket: Map.put(state.bucket, :ghosts, ghosts) |> Map.merge(complete)}
    }
  end

  defp handle_command(command, state) do
    IO.inspect(command, label: "Unhandled command")
    {:ok, state}
  end

  defp fetch_ghost(ghosts, object_id, start_version) do
    case Map.get(ghosts, object_id, Ghost.init()) do
      ghost = %Ghost{version: ^start_version} -> {:ok, ghost}
      _ -> {:error, "Invalid start version"}
    end
  end

  defp reduce_changes(%ChangeError{}, changes) do
    changes
  end

  defp reduce_changes(change = %Change{}, {:ok, updates, bucket}) do
    case change.o do
      "-" ->
        {removed, ghosts} = Map.pop(bucket.ghosts, change.id)
        {:ok, [{change.cv, removed} | updates], %{bucket | ghosts: ghosts}}

      "M" ->
        with {:ok, ghost} <- fetch_ghost(bucket.ghosts, change.id, change.sv),
             {:ok, updated} <- Simperium.JSONDiff.apply_diff(change.v, ghost.value),
             next_ghost <- Ghost.create_version(change.ev, updated),
             do:
               {:ok, [{change.cv, next_ghost}],
                %{bucket | cv: change.cv, ghosts: Map.put(bucket.ghosts, change.id, next_ghost)}}

      _ ->
        {:error, {:invalid_change_operation, change.o, change.cv}}
    end
  end

  defp reduce_changes(_change, {:error, _reason} = error), do: error

  defp default_state() do
    %{
      cv: :new,
      ghosts: %{},
      index_complete?: false
    }
  end

  defp broadcast_message(
         message,
         %{
           registry: registry,
           channel: %Channel{app_id: app_id} = channel
         }
       ) do
    Registry.dispatch(registry, :channel, fn entries ->
      for {pid, ^app_id} <- entries,
          do: send(pid, {:simperium, :channel, channel, message})
    end)
  end

  defp initial_index_request() do
    %Message.IndexRequest{include_data?: true}
  end
end
