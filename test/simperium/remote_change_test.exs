defmodule Simperium.RemoteChangeTest do
  use ExUnit.Case

  alias Simperium.RemoteChange

  test "make remote change" do
    change =
      RemoteChange.create("lol", "abcd", "object-id", 0, 1, "M", %{"o" => "+", "v" => "hello"}, [
        "abcd"
      ])

    assert %RemoteChange{
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
