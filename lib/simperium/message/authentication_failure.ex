defmodule Simperium.Message.AuthenticationFailure do
  @moduledoc """
  After a `Simperium.Message.BucketInit` is sent, simperium.com [sends
  an `auth:*` response](https://github.com/Simperium/simperium-protocol/blob/master/SYNCING.md#authorization).

  Auth failures contain a JSON payload with a `msg` and `code` to communicate
  the failure reason.

      iex> "0:auth:{\\"msg\\":\\"Invalid token\\",\\"code\\":400}" |> parse()
      {:ok, {:bucket, 0, %Message.AuthenticationFailure{message: "Invalid token", code: 400}}}
  """
  defstruct [:message, :code]
end
