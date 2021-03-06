defmodule Ingest.JSONFeed do
  @doc """
  ATM uses `Jason.decode!/1`

      iex> \"\"\"
      ...> {"hello": "world"}
      ...> \"\"\"
      ...> |> Ingest.JSONFeed.parse()
      {:ok, %{"hello" => "world"}}
  """
  def parse(content) do
    Jason.decode(content)
  end
end
