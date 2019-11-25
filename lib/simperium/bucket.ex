defmodule Simperium.Bucket do
  use GenServer

  alias Simperium.RemoteChange
  alias Simperium.Ghost
  alias Simperium.Message

  @moduledoc """
  `GenServer` implementation that performs Simperium realtime syncing.

  See `Simperium.Client.create_bucket/3`.

      iex> {:ok, client} = Simperium.Client.start_link()
      ...> {ok, bucket} = Simperium.Client.create_bucket(client, "notes", "supersecure");

  """

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
    GenServer.call(bucket, {:get, id})
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
  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  #
  # Server
  #

  @impl true
  def init(:new) do
    {:ok, default_state()}
  end

  @impl true
  def init(state) when is_map(state) do
    {:ok, Map.merge(default_state(), state)}
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
    {:reply, %Message.IndexRequest{include_data?: true}, state}
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

  defp fetch_ghost(ghosts, object_id, start_version) do
    case Map.get(ghosts, object_id, Ghost.init()) do
      ghost = %Ghost{version: ^start_version} -> {:ok, ghost}
      _ -> {:error, "Invalid start version"}
    end
  end

  defp reduce_changes(change = %RemoteChange{}, {:ok, updates, state}) do
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
end
