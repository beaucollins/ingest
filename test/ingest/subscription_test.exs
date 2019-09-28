defmodule Ingest.SubscriptionTest do
  use ExUnit.Case

  doctest Ingest.Subscription

  test "mnesia" do
    File.mkdir_p("tmp/mnesia-test")
    :mnesia.create_schema([node()])
    assert :ok === :mnesia.start()
    assert { :atomic, :ok } === :mnesia.create_table(:thing, attributes: [:id, :name])
    assert :stopped === :mnesia.stop()
  end
end
