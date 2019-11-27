defmodule Simperium.Message.Log do
  @moduledoc """
  Simperium can send `log:*` messages to request clients to send extra
  information about the client's state back to teh Simperium.com service
  for debugging purpose.

      iex> "log:1" |> parse()
      {:ok, {:connection, %Message.Log{mode: 1}}}
  """
  defstruct [:mode]
end
