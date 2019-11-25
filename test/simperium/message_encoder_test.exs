defmodule Simperium.MessageEncoderTest do
  use ExUnit.Case

  import Simperium.MessageEncoder
  alias Simperium.Message

  test "BucketInit" do
    message = %Message.BucketInit{
      clientid: "mock-client-id",
      app_id: "mock-app-id",
      name: "mock-bucket-name",
      token: "supersecure"
    }

    assert "init:" <> Jason.encode!(message) == encode(message)
  end

  test "Heartbeat" do
    assert "h:2347" == encode(%Message.Heartbeat{count: 2347})
  end
end
