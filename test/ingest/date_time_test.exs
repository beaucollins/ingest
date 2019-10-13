defmodule Ingest.DateTimeTest do
  use ExUnit.Case, async: true

  test "fails to parse" do
    assert_raise RuntimeError, fn ->
      Ingest.DateTime.parse!("")
    end
  end

  test "parses successfully" do
    date = Ingest.DateTime.parse!("2018-02-05 12:30:00 UTC")

    assert date == ~U[2018-02-05 12:30:00Z]
  end
end
