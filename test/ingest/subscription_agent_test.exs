defmodule Ingest.SubscriptionAgentTest do
  use ExUnit.Case, async: true

  doctest Ingest.SubscriptionAgent

  setup do
    {:ok, subs} = Ingest.SubscriptionAgent.start_link()
    %{subs: subs}
  end

  test "start agent", %{subs: subs} do
    assert [] === Ingest.SubscriptionAgent.list(subs)
  end
end
