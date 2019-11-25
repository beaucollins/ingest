defmodule Simperium.Heartbeat do
  use GenServer

  def start_link(monitor, opts \\ []) do
    GenServer.start_link(__MODULE__, monitor, opts)
  end

  ###
  # Client
  ###
  def defer(heartbeat) do
    GenServer.cast(heartbeat, :defer)
  end

  def start(heartbeat) do
    GenServer.cast(heartbeat, :start)
  end

  def stop(heartbeat) do
    GenServer.cast(heartbeat, :stop)
  end

  def set_beat(heartbeat, count) do
    GenServer.cast(heartbeat, {:heartbeat, count})
  end

  @impl true
  def init(monitor) do
    {:ok, %{monitor: monitor}}
  end

  @impl true
  def handle_cast({:heartbeat, count}, state) do
    {
      :noreply,
      state
      |> set_count(count)
      |> stop_timers()
      |> schedule_heartbeat()
    }
  end

  def handle_cast(:start, state) do
    {
      :noreply,
      state
      |> stop_timers()
      |> reset_count()
      |> schedule_heartbeat()
    }
  end

  def handle_cast(:stop, state) do
    {
      :noreply,
      state |> stop_timers()
    }
  end

  def handle_cast(:defer, state) do
    {
      :noreply,
      state
      |> stop_timers()
      |> schedule_heartbeat()
    }
  end

  @impl true
  def handle_cast(msg, state) do
    IO.inspect(msg, label: "casted")
    {:noreply, state}
  end

  @impl true
  def handle_info({:heartbeat, :beat}, state) do
    # notify we need to send a heartbeat out
    send(monitor(state), {:heartbeat, :beat, next_beat(state)})
    {:noreply, state |> schedule_timeout()}
  end

  def handle_info({:heartbeat, :timeout}, state) do
    # notify that we expired
    send(monitor(state), {:heartbeat, :timeout})
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp schedule_heartbeat(state) do
    Map.put(
      state,
      :beat,
      Process.send_after(self(), {:heartbeat, :beat}, 5_000)
    )
  end

  defp schedule_timeout(state) do
    Map.put(
      state,
      :timeout,
      Process.send_after(self(), {:heartbeat, :timeout}, 10_000)
    )
  end

  defp stop_timers(state) do
    state
    |> cancel_timer(:beat)
    |> cancel_timer(:timeout)
  end

  defp cancel_timer(state, name) do
    case Map.fetch(state, name) do
      :error ->
        state

      {:ok, timer} ->
        Process.cancel_timer(timer)
        state
    end
  end

  defp reset_count(state) do
    set_count(state, 0)
  end

  defp set_count(state, count) do
    Map.put(state, :count, count)
  end

  defp monitor(state) do
    Map.get(state, :monitor)
  end

  defp count(state) do
    Map.get(state, :count, 0)
  end

  defp next_beat(state) do
    count(state) + 1
  end
end
