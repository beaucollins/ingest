defmodule Simperium.Message.ChangeRequest do
  @moduledoc """
  Send a change for a bucket object.

      iex> Message.ChangeRequest.add_object("client-ex-1", "curent-cv", "unique-ccid", "object-key", %{"title" => %{ "o" => "+", "v" => "Hello"}})
      ...> |> encode()
      ~s(c:{"ccid":"unique-ccid","clientid":"client-ex-1","id":"object-key","o":"M","sv":0,"v":{"title":{"o":"+","v":"Hello"}}})
  """
  @enforce_keys [:ccid, :id, :o]
  defstruct [:clientid, :cv, :ev, :sv, :id, :o, :v, :ccid, :d]

  @doc """
  Creates a change request that adds a new object with key `object_id` to a bucket.
  """
  def add_object(clientid, cv, ccid, object_id, object_diff) do
    %__MODULE__{
      clientid: clientid,
      cv: cv,
      ccid: ccid,
      id: object_id,
      v: object_diff,
      o: "M",
      sv: 0
    }
  end
end

defimpl Simperium.MessageEncoder, for: Simperium.Message.ChangeRequest do
  def encode(change = %Simperium.Message.ChangeRequest{}) do
    keys = [:clientid, :v, :sv, :id, :o, :ccid]

    "c:" <> Jason.encode!(Map.take(change, keys))
  end
end
