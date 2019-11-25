defmodule Simperium.Client do
  @moduledoc """
  Process that implements realtime syncing with Simperium.com for a single
  Simperium App ID.
  """
  @doc """
  Specification for starting a Simperium sync client.
  """
  use GenServer

  alias Simperium.Message

  ##
  # Client
  ##

  @doc """
  Start a process that syncs Simperium.com data.
  """
  def start_link(app_id, opts \\ []) when is_binary(app_id) do
    GenServer.start_link(__MODULE__, app_id, opts)
  end

  @doc """
  Start a process that syncs a bucket.
  """
  def create_bucket(client, bucket_name, auth_token) do
    GenServer.call(client, {:bucket, bucket_name, auth_token})
  end

  @doc """
  Send a Simperium real-time sync client command.

  See `Simperium.Message` for available commands.
  """
  def send_message(client, {:send, bucket, msg}) do
    GenServer.call(client, {:send, bucket, msg})
  end

  ##
  # Server
  ##
  @impl true
  def init(app_id) do
    with {:ok, heartbeat} <- Simperium.Heartbeat.start_link(self()),
         {:ok, connection} <- Simperium.Connection.start_link(%{app_id: app_id, monitor: self()}),
         :ok <- Simperium.Heartbeat.start(heartbeat),
         do: {:ok, %{heartbeat: heartbeat, connection: connection, app_id: app_id}}
  end

  @impl true
  def handle_call({:bucket, bucket_name, auth_token}, _from, state) do
    # Step 1) Check for a bucket process at bucket_name
    # Step   a) If no process, start one
    # Step    i) If connected ask for init command
    # Step    ii) Ensure init with init cmd
    # Step    ii) Register bucket (two way communication for sync)

    # Step   b) Process exists return bucket

    # Step 2) Return bucket
    # Looks like we need to check for a Simperium.Bucket with the same
    message = %Simperium.Message.BucketInit{
      clientid: "the-missile-knows-where-it-is",
      app_id: state.app_id,
      name: bucket_name,
      token: auth_token
    }

    # check if we have a bucket running or not?
    # register the bucket with a channel number
    # if bucket is not yet initalized, send bucket needs
    # to send an init message
    Simperium.Connection.send_bucket_message(state.connection, 0, message)
    {:reply, {}, state}
  end

  def handle_call({:send, channel, msg}, _from, state) do
    Simperium.Connection.send_bucket_message(state.connection, channel, msg)
    {:reply, {}, state}
  end

  @impl true
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:simperium, {:connection, %Message.Heartbeat{count: beat}}}, state) do
    Simperium.Heartbeat.set_beat(state.heartbeat, beat)
    {:noreply, state}
  end

  @impl true
  def handle_info({:heartbeat, :beat, count}, state) do
    Simperium.Connection.send_connection_message(state.connection, %Message.Heartbeat{
      count: count
    })

    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.puts("Received #{inspect(msg)}")
    {:noreply, state}
  end
end
