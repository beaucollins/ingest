defmodule Simperium.Message.IndexPage do
  @moduledoc """
  Contains a page of the index. Sent by Simperium.com after a `Simperium.Message.IndexeRequest` is sent.

      iex> ~s(0:i:{"current": "5119dafb37a401031d47c0f7", "index": [{"id": "one", "v": 2}], "mark": "5119450b37a401031d3bfdb9"})
      ...> |> parse()
      {:ok, { :bucket, 0, %Message.IndexPage{
        current: "5119dafb37a401031d47c0f7",
        index: [%{"id" => "one", "v" => 2}],
        mark: "5119450b37a401031d3bfdb9"
      }}}
  )
  """
  defstruct [:current, :index, :mark]

  def from_map(map) when is_map(map) do
    %__MODULE__{
      current: Map.get(map, "current"),
      index: Map.get(map, "index", []),
      mark: Map.get(map, "mark")
    }
  end
end

defimpl Simperium.MessageDebug, for: Simperium.Message.IndexPage do
  def debug(%Simperium.Message.IndexPage{mark: mark, current: current, index: index}) do
    "📖 current: #{current} items: #{length(index)} next: #{mark}"
  end
end
