defmodule Simperium.Message.ChangeVersion do
  @moduledoc """
  Sent by a `Simperium.Client`.

  A `ChangeVersion` represents a the current version of the Bucket's state known by the client.

  To check if there are any new changes to by applied to te bucket, a client can send its
  current known `cv`.

      iex> %Message.ChangeVersion{cv: "abc"} |> encode()
      "cv:abc"

  `Simperium.Client` will prefix the proper channel number.

  If the `"cv:abc"` is unknown to Simperium.com, it will respond with `Simperium.Message.UnknownChangeVersion` (`"cv:?"`)
  """
  defstruct [:cv]
end
