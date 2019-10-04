defmodule Ingest.SubscriptionAgentTest do
  use ExUnit.Case

  doctest Ingest.Subscription

  test "start agent" do
    {:ok, pid} = Ingest.SubscriptionAgent.start_link(nil)
    {:error, {:already_started, ^pid}} = Ingest.SubscriptionAgent.start_link(nil)

    assert [] === Ingest.SubscriptionAgent.subs()
  end
end
