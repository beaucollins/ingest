defmodule Simperium.RemoteChangeTest do
  use ExUnit.Case

  alias Simperium.Change

  test "make remote change" do
    change =
      Change.create("lol", "abcd", "object-id", 0, 1, "M", %{"o" => "+", "v" => "hello"}, [
        "abcd"
      ])

    assert %Change{
             clientid: "lol",
             cv: "abcd",
             id: "object-id",
             sv: 0,
             ev: 1,
             o: "M",
             v: %{"o" => "+", "v" => "hello"},
             ccids: ["abcd"]
           } == change
  end
end
