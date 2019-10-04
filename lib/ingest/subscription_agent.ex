defmodule Ingest.SubscriptionAgent do
  use Agent

  @doc """
  This is a test

      iex> Ingest.SubscriptionAgent.start_link(nil)
      :ok
      iex> Ingest.SubscriptionAgent.subs()
      []
  """
  def subs do
    Agent.get(__MODULE__, & &1)
  end

  def start_link(_state) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end
end
