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

  The `Ingest` application uses `Traverse` to find `<link type="alternate">` elements find RSS feeds
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
    to iterate oven each node within the DOM and execute a compatible matcher function.
  """
  @doc """
  Parses content into a DOM graph.

  Currently uses `:mochiweb_html.parse/1`.
  """
  def parse(content), do: :mochiweb_html.parse(content)

  @doc """
  Query a document or document fragment using a Matcher to identify parts of the
  DOM to collect.

  See `Traverse.Matcher.query/2`.
  """
  def query(document, matcher) when is_binary(document) do
    document
    |> Traverse.parse()
    |> query(matcher)
  end

  def query(document, matcher), do: Traverse.Matcher.query(document, matcher)

  @doc """
  Query a document for all matching fragments.

  See `Traverse.Matcher.query_all/2`
  """
  def query_all(document, matcher) when is_binary(document) do
    document
    |> Traverse.parse()
    |> query_all(matcher)
  end

  def query_all(document, matcher), do: Traverse.Matcher.query_all(document, matcher)

  @doc """
  Transform the content of an HTML document.

  See `Traverse.Transformer.map/2`.

  A transformer is as function that takes in an HTML fragment (node, node list, text, or comment)
  and returns a fragment to be used in the new returned document.

  Remove all `<script>` tags from a document:

      iex> import Traverse.Transformer
      iex> \"\"\"
      ...> <html>
      ...>  Hello
      ...>  <script type="text/javascript">alert("🧨");</script>
      ...>  There
      ...> \"\"\"
      ...> |> Traverse.parse()
      ...> |> Traverse.map(transform(
      ...>   Traverse.Matcher.element_name_is("script"),
      ...>   fn _node -> [] end
      ...> ))
      ...> |> Traverse.Document.to_string()
      ~s[<html>\\n Hello\\n \\n There\\n</html>]

  """
  def map(document, transformer), do: Traverse.Transformer.map(document, transformer)

  @doc """
  Convert a document fragment into a string.

  Note: there's a bug in the :mochiweb_html.parse/1 function that eats the
  space between two HTML nodes (e.g. `<strong>` and `<em>`):

      iex> ~s[<html><body><div><strong>Hello</strong> <em>World</em></div>]
      ...> |> Traverse.query(Traverse.Matcher.element_name_is("div"))
      ...> |> Traverse.to_string()
      "<div><strong>Hello</strong><em>World</em></div>"
  """
  def to_string(fragment), do: Traverse.Document.to_string(fragment)
end
