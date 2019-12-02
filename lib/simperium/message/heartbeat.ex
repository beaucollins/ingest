defmodule Simperium.Message.Heartbeat do
  @moduledoc """
  `Simperium.Client` sends and rececives `Message.Heartbeat` messages to keep a connection
  alive.

  Receiving:

      iex> "h:100" |> parse()
      {:ok, {:connection, %Message.Heartbeat{count: 100}}}

  Sending:

      iex> %Message.Heartbeat{count: 101} |> encode()
      "h:101"
  """
  defstruct [:count]
end
