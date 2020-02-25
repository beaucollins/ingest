defmodule Traverse.Document do
  @moduledoc """
  Utilities for traversing a DOM from `Traverse.parse/1`.
  """

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
    |> stream(Traverse.Matcher.is_text_element(), mode: :depth)
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

  ["img", "hr"]
  |> Enum.each(fn element ->
    IO.puts(element)

    defp as_string({unquote(element), atts, []}) do
      "<" <> unquote(element) <> attribute_list_string(atts) <> " />"
    end
  end)

  defp as_string({element, atts, []}) do
    as_string({element, atts, [""]})
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

  @doc """
  Stream over every node within the document. Optionally provide a
  matcher that filters for specific nodes.

  Supports a depth first or breadth first graph traversal via `options[:mode]`.

  Default mode is `:breadth`.

  Example, when searching by `:breadth`, sibling nodes appear before child nodes:

      iex> "<div><span><strong></strong></span><em></em></div>"
      ...> |> Traverse.parse()
      ...> |> Traverse.Document.stream([mode: :breadth])
      ...> |> Enum.map(fn {tag, _, _ } -> tag end)
      ["div", "span", "em", "strong"]

   When searching by `:depth`, child nodes appear before sibling nodes.

      iex> "<div><span><strong></strong></span><em></em></div>"
      ...> |> Traverse.parse()
      ...> |> Traverse.Document.stream([mode: :depth])
      ...> |> Enum.map(fn {tag, _, _ } -> tag end)
      ["div", "span", "strong", "em"]
  """
  def stream(document, matcher \\ nil, options \\ [mode: :breadth])

  def stream(document, [mode: _mode] = options, _options) do
    stream(document, nil, options)
  end

  def stream(document, matcher, [mode: mode] = _options) do
    stream =
      document
      |> Stream.unfold(fn
        # No more items, we're done
        [] ->
          nil

        # A single node, should be the root node
        # return the node and queue up the node's children
        {_, _, children} = node ->
          {node, children}

        # A list of nodes to process, the first beig a DOM node
        # Append its children to the list to be iterated on later
        # NOTE: prepending items is preferred to `Kernal.++/2`
        [{_, _, children} = node | rest] ->
          {node,
           case mode do
             :breadth -> rest ++ children
             :depth -> children ++ rest
           end}

        # A text node or comment node, return the node and continue
        # with the rest
        [text | rest] ->
          {text, rest}

        # When streaming a document fragment that is empty as the
        # initial item, Stream.unfold/3 receives nil, Stream is done
        nil ->
          nil
      end)

    case matcher do
      nil -> stream
      exists -> Stream.filter(stream, exists)
    end
  end

  @doc """
  Stream over a DOM node's children.
  """
  def stream_children(node, matcher) do
    node |> children() |> stream(matcher)
  end

  @doc """
  Find the first element in the document that matches the matcher
  """
  def query(document, matcher) do
    stream(document, matcher)
    |> Stream.take(1)
    |> Enum.to_list()
    |> case do
      [] -> nil
      [head | _rest] -> head
    end
  end

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
    stream(document, matcher) |> Enum.to_list()
  end
end
