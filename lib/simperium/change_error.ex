defmodule Simperium.ChangeError do
  @moduledoc """
  Changes that failed.
  """
  defstruct [:error, :id, :ccids, :clientid]
end
