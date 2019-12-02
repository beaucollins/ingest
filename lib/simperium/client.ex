defmodule Simperium.Client do
  @moduledoc """
  Process that implements real-time syncing with Simperium.com for a single
  Simperium App ID.

  Currently it's all setup for debugging with noisy logging and debug traces.

      iex> {:ok, client} = Simperium.start_link "funny-nerfherder-g809"
      ...> {:ok, bucket } = Simperium.create_bucket client, "note", "super-secure-token"

  You will now see the messages between the `Simperium.Connection` and the Simperium
  real-time syncing service.

  ```
  <=: {:bucket, 0,
    %Simperium.Message.AuthenticationSuccess{identity: "REDACTED"}}
  <=: {:connection, %Simperium.Message.Heartbeat{count: 16}}
  <=: {:connection, %Simperium.Message.Heartbeat{count: 18}}
  <=: {:connection, %Simperium.Message.Heartbeat{count: 20}}
  ```

  Make a changes on another client:

  ```
  <=: {:bucket, 0,
    %Simperium.Message.RemoteChanges{
    changes: [
      %Simperium.RemoteChange{
        ccids: ["a6386cc4-81db-4f24-a2c0-acdb47f28bfe"],
        clientid: "node-3a3c39e2-4cd7-48e0-a487-2b358b29039f",
        cv: "5ddbfef94806f90fe648e8ec",
        ev: 10,
        id: "1a2d1cfe7cba46c3a8b5f1b3797643d8",
        o: "M",
        sv: 9,
        v: %{
          "content" => %{"o" => "d", "v" => "=27\t+%0A%0Aadding something"},
          "modificationDate" => %{"o" => "r", "v" => 1574698743}
        }
      }
    ]
    }}
  ```

  All messages understood by `Simperium.Client` are defined as structs in
  the `Simperium.Message` module.

  **TODO**: Seperate/identify incoming vs outgoing messages. `Simperium.Message.parse/1`
  turns incoming Websocket frames into messages. Implementing `Simperium.MessageEncoder` for a
  message means it is an outgoing message understood by `Simperium.Message.encode/1`.
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
  def create_bucket(client, auth_token, bucket) do
    GenServer.call(client, {:bucket, auth_token, bucket})
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
    state =
      with {:ok, heartbeat} <- Simperium.Heartbeat.start_link(self()),
           {:ok, _} <- Registry.start_link(keys: :duplicate, name: Simperium.MessageConsumer),
           {:ok, connection} <-
             Simperium.Connection.start_link(%{
               app_id: app_id,
               registry: Simperium.MessageConsumer
             }),
           :ok <- Simperium.Heartbeat.start(heartbeat),
           do:
             {:ok,
              %{
                heartbeat: heartbeat,
                connection: connection,
                app_id: app_id,
                buckets: %{}
              }}

    # Messages comming from the Simperium.Connection for this app
    Registry.register(Simperium.MessageConsumer, :connection, app_id)
    Registry.register(Simperium.MessageConsumer, :bucket, app_id)
    Registry.register(Simperium.MessageConsumer, :channel, app_id)

    state
  end

  @impl true
  def handle_call({:bucket, auth_token, bucket_name}, _from, %{app_id: app_id} = state) do
    # Step 1) Check for a bucket process at bucket_name
    # Step   a) If no process, start one
    # Step    i) If connected ask for init command
    # Step    ii) Ensure init with init cmd
    # Step    ii) Register bucket (two way communication for sync)

    # Step   b) Process exists return bucket

    # Step 2) Return bucket
    # Looks like we need to check for a Simperium.Bucket with the same

    # which channel is this?
    buckets =
      Map.put_new_lazy(state.buckets, {auth_token, bucket_name}, fn ->
        # Bucket "emits" messages here

        channel_number = map_size(state.buckets)

        channel = %Simperium.Bucket.Channel{
          app_id: app_id,
          auth_token: auth_token,
          channel: channel_number,
          bucket_name: bucket_name
        }

        # TODO: Dynamic Supervisor
        {:ok, bucket} =
          Simperium.Bucket.start_link(
            registry: Simperium.MessageConsumer,
            channel: channel
          )

        message = %Simperium.Message.BucketInit{
          clientid: "the-missile-knows-where-it-is",
          app_id: state.app_id,
          name: bucket_name,
          token: auth_token,
          cmd: Simperium.Bucket.create_init_command(bucket)
        }

        Simperium.Connection.send_bucket_message(state.connection, channel_number, message)
        # TODO: send init message for this channel
        # Registry.dispatch(Simperium.MessageConsumer, :outbound, fn entries ->
        #   for {pid, ^app_id} <- entries, do: send(pid, {:simperium, :send, channel, message})
        # end)

        # If we're connected send the init
        {channel, bucket}
      end)

    # check if we have a bucket running or not?
    # register the bucket with a channel number
    # if bucket is not yet initalized, send bucket needs
    # to send an init message
    {:reply, Map.get(buckets, {auth_token, bucket_name}), %{state | buckets: buckets}}
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

  @impl true
  def handle_info({:simperium, :connection, %Message.Heartbeat{count: beat}}, state) do
    Simperium.Heartbeat.set_beat(state.heartbeat, beat)
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:simperium, :channel, %Simperium.Bucket.Channel{channel: channel}, message},
        state
      ) do
    Simperium.Connection.send_bucket_message(state.connection, channel, message)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
