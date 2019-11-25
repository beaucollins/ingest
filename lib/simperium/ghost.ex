defmodule Simperium.Ghost do
  defstruct [:version, :value]

  def init() do
    %__MODULE__{version: 0, value: %{}}
  end

  def create_version(version, value) do
    %__MODULE__{version: version, value: value}
  end
end
