defmodule Traverse do
  @doc """
  Parses content into a DOM graph.

  Currently uses `:mochiweb_html.parse/1`.
  """
  def parse(content), do: :mochiweb_html.parse(content)
end
