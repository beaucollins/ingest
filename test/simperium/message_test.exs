defmodule Simperium.MessageTest do
  use ExUnit.Case

  import Simperium.Message
  alias Simperium.Message

  doctest Message
  doctest Message.AuthenticationSuccess
  doctest Message.AuthenticationFailure
  doctest Message.ChangeVersion
  doctest Message.ChangeRequest
  doctest Message.Heartbeat
  doctest Message.IndexPage
  doctest Message.IndexRequest
  doctest Message.Log
  doctest Message.ObjectVersion
  doctest Message.RemoteChanges
  doctest Message.UnknownChangeVersion
  doctest Message.UnknownObjectVersion

  test ":invalid_message_type" do
    assert {:error, :invalid_message_type} = parse("lol")
  end

  test ":unknown_message_type" do
    assert {:error, :unknown_message_type} = parse("l:ol")
  end

  describe "connection" do
    test "log" do
      assert {:ok, {:connection, %Message.Log{mode: 1}}} = parse("log:1")
      assert {:error, :invalid_log_mode} = parse("log:a")
    end

    test "h" do
      assert {:ok, {:connection, %Message.Heartbeat{count: 4}}} = parse("h:4")
      assert {:error, :invalid_heartbeat} = parse("h:a")
    end
  end

  describe "bucket" do
    test "c" do
      assert {:ok, {:bucket, 0, %Message.RemoteChanges{changes: changes}}} =
               parse(
                 ~s(0:c:[{"clientid": "sjs-2012121301-9af05b4e9a95132f614c", "id": "newobject", "o": "M", "v": {"new": {"o": "+", "v": "object"}}, "ev": 1, "cv": "511aa58737a401031d57db90", "ccids": ["3a5cbd2f0a71fca4933fff5a54d22b60"]}])
               )

      assert [
               %Simperium.RemoteChange{
                 clientid: "sjs-2012121301-9af05b4e9a95132f614c",
                 id: "newobject",
                 o: "M",
                 v: %{"new" => %{"o" => "+", "v" => "object"}},
                 ev: 1,
                 cv: "511aa58737a401031d57db90",
                 ccids: ["3a5cbd2f0a71fca4933fff5a54d22b60"]
               }
             ] == changes
    end

    test "e" do
      assert {:ok, {:bucket, 5, %Message.ObjectVersion{key: "thing", version: 2, data: %{}}}} ==
               parse("5:e:thing.2\n{}")

      assert {:ok, {:bucket, 5, %Message.UnknownObjectVersion{key: "other.thing", version: 200}}} ==
               parse("5:e:other.thing.200\n?")

      assert {:error, _} = parse("0:e:1\n{}")
    end

    test "cv" do
      assert {:ok, {:bucket, 5, %Message.UnknownChangeVersion{}}} = parse("5:cv:?")
    end

    test "auth failure" do
      assert {:ok,
              {:bucket, 0, %Message.AuthenticationFailure{code: 400, message: "Token malformed"}}} ==
               parse("0:auth:{\"msg\": \"Token malformed\", \"code\": 400}")
    end

    test "auth success" do
      assert {:ok, {:bucket, 237, %Message.AuthenticationSuccess{identity: "user@simperium.com"}}} ==
               parse("237:auth:user@simperium.com")
    end
  end
end
