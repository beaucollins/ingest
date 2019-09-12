defmodule Traverse.Document do
  @moduledoc """
  Utilities for traversing a DOM from `Traverse.parse/1`.
  """

  @doc """
  Find DOM elements that return `true` for the given matcher.

  Find all nodes that have`id="two"`

      iex> Traverse.parse(~s(<html><body><div /><div id="two">Hello</div>))
      ...> |> Traverse.Document.query_all(Traverse.Matcher.id_is("two"))
      [{"div", [{"id", "two"}], ["Hello"]}]

  Find all nodes that are `<span>` elements:

      iex> Traverse.parse(~s(<html><body><span>1</span><span>2</span><div><span>3</span></html>))
      ...> |> Traverse.Document.query_all(Traverse.Matcher.element_name_is("span"))
      [{"span", [], ["1"]}, {"span", [], ["2"]}, {"span", [], ["3"]}]

  Find all nodes that are `<span>` elements and have a `class="important"` attribute:

      iex> import Traverse.Matcher
      iex> Traverse.parse(~s(
      ...>   <html>
      ...>     <span>Not important</span>
      ...>     <span class="important">Important</span>
      ...>     <div class="important"/>
      ...> ))
      ...> |> Traverse.Document.query_all(
      ...>     attribute_is("class", "important")
      ...>     |> and_matches(element_name_is("span"))
      ...> )
      [{"span", [{"class", "important"}], ["Important"]}]
  """
  def query_all(document, matcher) do
    Traverse.Matcher.query_all(document, matcher)
  end

  def query(document, matcher) do
    Traverse.Matcher.query(document, matcher)
  end

  @doc """
  Children of a given node. If `node` is not a element Tuple, returns
  an empty list.

      iex> Traverse.Document.children("text node")
      []

      iex> Traverse.parse(~s(<html><head /><body>Hello))
      ...> |> Traverse.Document.children()
      [{"head", [], []}, {"body", [], ["Hello"]}]
  """
  def children(node) do
    case node do
      {_name, _attributes, children} ->
        children

      _ ->
        []
    end
  end

  @doc """
  Given a fragment, returns the text content of the DOM node. Text nodes are
  trimmed with `String.trim/1`

      iex> :mochiweb_html.parse(~s(
      ...>   <html>
      ...>      <body>
      ...>        The beginning
      ...>        <div>
      ...>          Hello
      ...> ))
      ...> |> Traverse.Document.node_content()
      "The beginning\\nHello"

  When no text content present:

      iex> Traverse.parse("<html><body><div>")
      ...> |> Traverse.Document.node_content()
      ""

  """
  def node_content(fragment, concat_with \\ "\n") do
    fragment
    |> Traverse.Matcher.stream(Traverse.Matcher.is_text_element(), mode: :depth)
    |> Stream.map(&String.trim/1)
    |> Enum.reduce(
      "",
      fn
        content, "" ->
          content

        content, previous ->
          previous <> concat_with <> content
      end
    )
  end

  @doc """
  Fetch the value of the attribute named `name` from a DOM node.

      iex> {"input", [{"for", "other-node"}], []}
      ...> |> Traverse.Document.attribute("for")
      "other-node"

  When the attribute of `name` is not present the `defaultTo` value
  is returned.

      iex> {"a", [{"href", "htts://google.com"}], []}
      ...> |> Traverse.Document.attribute("target", :empty)
      :empty
  """
  def attribute({_type, attributes, _children} = _node, name, defaultTo \\ nil) do
    Enum.find(attributes, fn
      {key, _} when key == name -> true
      _ -> false
    end)
    |> case do
      {_, value} -> value
      _ -> defaultTo
    end
  end

  def to_string(document) do
    as_string(document)
  end

  defp as_string({element, atts, []}) do
    "<" <> element <> attribute_list_string(atts) <> " />"
  end

  defp as_string({element, atts, children}) do
    "<" <>
      element <>
      attribute_list_string(atts) <> ">" <> as_string(children) <> "</" <> element <> ">"
  end

  defp as_string(fragment) when is_list(fragment) do
    Enum.reduce(fragment, "", fn
      node, string ->
        string <> as_string(node)
    end)
  end

  defp as_string(fragment) when is_binary(fragment) do
    fragment
  end

  defp as_string({:comment, content}) do
    "<!--" <> content <> "-->"
  end

  defp attribute_list_string(atts) do
    case Traverse.Document.AttributeList.to_string(atts) do
      "" -> ""
      str -> " " <> str
    end
  end

  defmodule AttributeList do
    def to_string(attribute_list) do
      Enum.reduce(attribute_list, "", fn
        attr, "" ->
          as_string(attr)

        attr, list ->
          list <> " " <> as_string(attr)
      end)
    end

    defp as_string({key, value}) do
      key <> "=\"" <> value <> "\""
    end
  end
end
