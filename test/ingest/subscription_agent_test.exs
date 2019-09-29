defmodule Ingest.SubscriptionAgentTest do
  use ExUnit.Case

  test "start agent" do
    Ingest.SubscriptionAgent.start_link(nil)

    assert :ok === Ingest.SubscriptionAgent.started?()
  end
end
