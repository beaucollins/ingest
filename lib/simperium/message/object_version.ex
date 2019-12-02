defmodule Simperium.Message.ObjectVersion do
  @moduledoc """
  Sent by a client to request a bucket object stored at `keyname` at
  a specific version.

      iex> %Message.ObjectVersion{key: "a-keyname", version: 1} |> encode()
      "e:a-keyname.1"

  If Simperium.com has the object at the requested version it replies with:

      iex> ~s(0:e:a-keyname.1\\n{"some":"data"}) |> parse()
      {:ok, {:bucket, 0, %Message.ObjectVersion{
        key: "a-keyname",
        version: 1,
        data: %{"some" => "data"}
      }}}

  If the bucket does not have the data for the key at that version it will send
  `Simperium.Message.UnknownObjectVersion` (`e:a-keyname.1\n?`)
  """
  defstruct [:key, :version, :data]
end
