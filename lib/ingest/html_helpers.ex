defmodule Ingest.HTMLHelpers do

  def text(body, matcher) do
    body
    |> Traverse.parse()
    |> Traverse.query(matcher)
    |> Traverse.Document.node_content()
  end

end
