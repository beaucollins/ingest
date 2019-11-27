defmodule Simperium.Message.UnknownChangeVersion do
  @moduledoc """
  Sent by Simperium.com after receiving a `Simperium.Message.ChangeVersion` that is
  unknown to Simperium.com.

      iex> "0:cv:?" |> parse()
      {:ok, {:bucket, 0, %Message.UnknownChangeVersion{}}}
  """
  defstruct []
end
