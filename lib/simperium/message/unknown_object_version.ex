defmodule Simperium.Message.UnknownObjectVersion do
  @moduledoc """
  Received when an object version is requested but Simperium does not
  know that object key at that version.

      iex> "0:e:keyname.1\\n?" |> parse()
      {:ok, {:bucket, 0, %Message.UnknownObjectVersion{
        key: "keyname",
        version: 1
      }}}

  """
  defstruct [:key, :version]
end
