defmodule Ingest.SubscriptionAgent do
  use Agent

  @doc """
  Get a list of subscriptions

      iex> case Ingest.SubscriptionAgent.start_link([]) do
      ...>  {:ok, subs} -> Ingest.SubscriptionAgent.list(subs)
      ...> end
      []
  """
  def list(subs) do
    Agent.get(subs, & &1)
  end

  def start_link(opts \\ []) do
    Agent.start_link(fn -> [] end, opts)
  end
end
