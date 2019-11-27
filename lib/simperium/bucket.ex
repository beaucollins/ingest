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

  @doc """
  """

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
  Apply a command to this bucket received by Simperium. See `Simperium.Message`.
  """
  def apply_command(bucket, command = %Message.RemoteChanges{}) do
    GenServer.call(bucket, {:apply_command, command})
  end

  @doc """
  Given a `Simperium.Bucket`s state, returns the init command that should be used when
  connecting to Simperium's real-time sync service.
  """
  def create_init_command(bucket) do
    GenServer.call(bucket, :init_command)
  end

  @doc """
  Start a `Simperium.Bucket` process. To function correctly it requires a `Simperium.Connection`.
  """
  def start_link(opts) do
    start_link(%{}, opts)
  end

  def start_link(state, opts) when is_map(state) do
    registry = Keyword.fetch!(opts, :registry)
    channel = Keyword.fetch!(opts, :channel)

    GenServer.start_link(
      __MODULE__,
      default_state()
      |> Map.merge(state)
      |> Map.merge(%{registry: registry, channel: channel}),
      opts |> Keyword.drop([:registry, :channel])
    )
  end

  #
  # Server
  #
  @impl true
  def init(%{registry: registry, channel: channel} = state) do
    Registry.register(registry, :bucket, channel)
    {:ok, state}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    {:reply, Map.get(state.ghosts, id), state}
  end

  @impl true
  def handle_call(:cv, _from, state) do
    {:reply, state.cv, state}
  end

  @impl true
  def handle_call(:init_command, _from, %{cv: :new, index_complete?: true} = state) do
    # no cv, but index is completed? No message needs to be sent
    {:reply, :noop, state}
  end

  @impl true
  def handle_call(:init_command, _from, %{cv: cv, index_complete?: true} = state) do
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
        %{index_complete?: false} = state
      ) do
    {:reply, {:error, :noindex}, state}
  end

  @impl true
  def handle_call({:apply_command, command = %Message.RemoteChanges{}}, _from, state) do
    # all changes must be applied now? or does this get queued up
    case command.changes |> Enum.reduce({:ok, [], state}, &reduce_changes/2) do
      {:ok, updates, new_state} -> {:reply, {:ok, updates}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:index_complete?, _from, %{index_complete?: index_complete?} = state) do
    {:reply, index_complete?, state}
  end

  def handle_call(:request_changes, _from, %{index_complete?: false} = state) do
    {:reply, {:error, :no_index}, state}
  end

  def handle_call(:request_changes, _form, %{cv: cv} = state) do
    broadcast_message(%Message.ChangeVersion{cv: cv}, state)
    {:reply, cv, state}
  end

  def handle_call(:reindex, _from, state) do
    broadcast_message(initial_index_request(), state)
    {:reply, :ok, state}
  end

  def handle_call({:put, id, value}, _from, state) do
    # build the Change and seind
    # TODO pending changes, network changes
    {operation, source} =
      case Map.get(state.ghosts, id) do
        nil ->
          {"+", Simperium.Ghost.create_version(0, %{})}

        ghost = %Simperium.Ghost{} ->
          {"M", ghost}
      end

    case Simperium.JSONDiff.create_diff(source.value, value) do
      {:ok, diff} ->
        change_request = %Simperium.Message.ChangeRequest{
          clientid: "the-missile-knows-where-it-is",
          cv: state.cv,
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
  def handle_info(
        {:simperium, :bucket, command = %Message.IndexPage{}},
        %{ghosts: ghosts} = state
      ) do
    ghosts =
      Enum.reduce(command.index, ghosts, fn %{"d" => data, "id" => id, "v" => version}, ghosts ->
        Map.put(ghosts, id, Ghost.create_version(version, data))
      end)

    complete =
      case Message.IndexRequest.next_page(command) do
        nil ->
          %{index_complete?: true, cv: command.current}

        request ->
          broadcast_message(request, state)
          %{index_complete?: false, cv: command.current}
      end

    {:noreply, state |> Map.put(:ghosts, ghosts) |> Map.merge(complete)}
  end

  @impl true
  def handle_info({:simperium, :bucket, command = %Simperium.Message.RemoteChanges{}}, state) do
    case command.changes |> Enum.reduce({:ok, [], state}, &reduce_changes/2) do
      {:ok, _updates, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @impl true
  def handle_info({:simperium, :bucket, message}, state) do
    IO.inspect(message, label: "Perform bucket command")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
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

  defp reduce_changes(change = %Change{}, {:ok, updates, state}) do
    case change.o do
      "-" ->
        {removed, ghosts} = Map.pop(state.ghosts, change.id)
        {:ok, [{change.cv, removed} | updates], %{state | ghosts: ghosts}}

      "M" ->
        with {:ok, ghost} <- fetch_ghost(state.ghosts, change.id, change.sv),
             {:ok, updated} <- Simperium.JSONDiff.apply_diff(change.v, ghost.value),
             next_ghost <- Ghost.create_version(change.ev, updated),
             do:
               {:ok, [{change.cv, next_ghost}],
                %{state | cv: change.cv, ghosts: Map.put(state.ghosts, change.id, next_ghost)}}

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

  defp broadcast_message(message, %{channel: %{app_id: app_id}} = state) do
    Registry.dispatch(state.registry, :channel, fn entries ->
      for {pid, ^app_id} <- entries,
          do: send(pid, {:simperium, :channel, state.channel, message})
    end)
  end

  defp initial_index_request() do
    %Message.IndexRequest{include_data?: true}
  end
end
