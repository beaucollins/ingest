defmodule IngestTest do
  use ExUnit.Case
  doctest Ingest

  test "greets the world" do
    assert Ingest.hello() == :world
  end
end
