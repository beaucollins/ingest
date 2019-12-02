defmodule Simperium.Message.AuthenticationSuccess do
  @moduledoc """
  After sending a successful `Simperium.Message.BucketInit` message Simperium replies
  with `0:auth:user@simperium.com`.

      iex> "0:auth:user@simperium.com" |> parse()
      {:ok, {:bucket, 0, %Message.AuthenticationSuccess{identity: "user@simperium.com"}}}
  """
  defstruct [:identity]
end
