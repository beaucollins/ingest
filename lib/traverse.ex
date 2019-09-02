defmodule Traverse do
  @moduledoc """
  Module for selecting DOM nodes within a graph using selectors that are analagous
  [Document.querySelector](https://developer.mozilla.org/en-US/docs/Web/API/Document/querySelector).

  For example, pull out the text from the `<title>` node within an HTML document:

      iex> \"\"\"
      ...> <html>
      ...>  <head><title>The Best Page on the Internet 🚀</title>
      ...> .. <body>
      ...> \"\"\"
      ...> |> Traverse.parse()
      ...> |> Traverse.query(Traverse.Matcher.element_name_is("title"))
      ...> |> Traverse.Document.node_content()
      "The Best Page on the Internet 🚀"

  In the `Ingest` application uses `Traverse` to find `<link type="alternate">` elements find RSS feeds
  for a given document.

      iex> import Traverse.Matcher
      iex> ~s(<html>
      ...>   <head>
      ...>     <link rel="alternate" type="application/json" href="http://example.blog/feed/rss"/>
      ...> )
      ...> |> Traverse.parse
      ...> |> query_all(
      ...>   element_name_is("link")
      ...>   |> and_matches("rel" |> attribute_is("alternate"))
      ...>)
      [{"link", [{"rel", "alternate"}, {"type", "application/json"}, {"href", "http://example.blog/feed/rss"}], []}]

    The workhorse of the query API is `Traverse.Matcher.stream/1` which uses `Stream.unfold/2`
    to interate oven each node within the DOM and execute a compatible matcher function.
  """
  @doc """
  Parses content into a DOM graph.

  Currently uses `:mochiweb_html.parse/1`.
  """
  def parse(content), do: :mochiweb_html.parse(content)

  @doc """
  Query a document or document fragment using a Matcher to identify parts of the
  DOM to collect.
  """
  def query(document, matcher), do: Traverse.Matcher.query(document, matcher)
end
