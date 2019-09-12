defmodule Traverse.Matcher do
  alias Traverse.Document

  @moduledoc """
  Functions for querying a DOM or DOM fragment.
  """
  @type matcher :: (:mochiweb_html.html_node() -> boolean)

  @doc """
  Find all elements that match the given matcher within the document
  """
  def find(document, matcher) do
    query_all(document, matcher)
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
  Find all elements in document that match the given matcher
  """
  def query_all(document, matcher) do
    stream(document, matcher) |> Enum.to_list()
  end

  def stream_children(node, matcher) do
    node |> Document.children() |> stream(matcher)
  end

  @doc """
  Stream over every node within the document. Optionally provide a
  matcher that filters for specific nodes.

  Supports a depth first or breadth first graph traversal via `options[:mode]`.

  Default mode is `:breadth`.

  Example, when searching by `:breadth`, sibling nodes appear before child nodes:

      iex> "<div><span><strong></strong></span><em></em></div>"
      ...> |> Traverse.parse()
      ...> |> Traverse.Matcher.stream([mode: :breadth])
      ...> |> Enum.map(fn {tag, _, _ } -> tag end)
      ["div", "span", "em", "strong"]

   When searching by `:depth`, child nodes appear before sibling nodes.

      iex> "<div><span><strong></strong></span><em></em></div>"
      ...> |> Traverse.parse()
      ...> |> Traverse.Matcher.stream([mode: :depth])
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
  Returns a matcher for a given element type.

      iex> import Traverse.Matcher
      iex> Traverse.parse(~s(
      ...>   <html>
      ...>     <head>
      ...>       <title>Cool beans</title>
      ...>     </head>
      ...>     <body>
      ...> ))
      ...> |> find(element_name_is("title"))
      [{"title", [], ["Cool beans"]}]
  """
  @spec element_name_is(String.t()) :: matcher
  def element_name_is(name) do
    fn
      {element, _attributes, _children} when element == name ->
        true

      _ ->
        false
    end
  end

  @doc """
  Matches an element if it is one of `element_names`.

  Can be a list or space seperated string of names.

      iex> ~s[<html><span></span><div></div><em></em>]
      ...> |> Traverse.query_all(Traverse.Matcher.element_is_one_of("div em"))
      [{"div", [], []}, {"em", [], []}]

  Or

      iex> ~s[<html><span></span><div></div><em></em>]
      ...> |> Traverse.query_all(Traverse.Matcher.element_is_one_of(["div", "em"]))
      [{"div", [], []}, {"em", [], []}]
  """
  def element_is_one_of(element_names) when is_list(element_names) do
    matches_any(element_names |> Enum.map(&element_name_is/1))
  end

  def element_is_one_of(element_names) when is_binary(element_names) do
    element_is_one_of(element_names |> String.split(" "))
  end

  @doc """
  Combines two matchers into a matcher that requires both to pass.

      iex> import Traverse.Matcher
      iex> Traverse.parse(~s(
      ...>   <html>
      ...>     <head>
      ...>       <title>Cool beans</title>
      ...>     </head>
      ...>     <body id="post-22">Stuff
      ...> ))
      ...> |> find(
      ...>   element_name_is("body") |> and_matches(
      ...>     ("id" |> attribute_is("post-22"))
      ...>   )
      ...> )
      [{"body", [{"id", "post-22"}], ["Stuff\\n "]}]
  """
  @spec and_matches(matcher, matcher) :: matcher
  def and_matches(fn1, fn2) do
    fn value -> fn1.(value) && fn2.(value) end
  end

  @doc """
  Combines two matchers into a matcher that passes if either matches.

      iex> import Traverse.Matcher
      iex> Traverse.parse(~s(<html><head><body><div id="post-5"/><span>))
      ...> |> query_all(
      ...>   contains_attribute("id") |> or_matches(element_name_is("span"))
      ...> )
      [
        {"div", [{"id", "post-5"}], []},
        {"span", [], []}
      ]
  """
  def or_matches(matcher1, matcher2) do
    fn value -> matcher1.(value) || matcher2.(value) end
  end

  @doc """
  Creates a matcher that matches nodes with the given `id` attribute.

      iex> Traverse.parse(~s(<html><div id="me">Hi.))
      ...> |> Traverse.Matcher.query(Traverse.Matcher.id_is("me"))
      {"div", [{"id", "me"}], ["Hi."]}
  """
  @spec id_is(String.t()) :: matcher
  def id_is(id), do: attribute_is("id", id)

  @doc """
  Creates a matcher that matches nodes with an attribute of `name`
  that matches the given `value`.

      iex> Traverse.parse(~s(<html><body class="special"))
      ...> |> Traverse.Matcher.query(Traverse.Matcher.attribute_is("class", "special"))
      {"body", [{"class", "special"}], []}
  """
  @spec attribute_is(String.t(), String.t()) :: matcher
  def attribute_is(name, value) do
    fn
      {_, atts, _} ->
        Enum.find(atts, false, fn
          {^name, ^value} -> true
          _ -> false
        end)

      _ ->
        false
    end
  end

  @doc """
  Finds elements in a DOM with attribute of `name` which has a value that begins
  with `prefix`.
  """
  def attribute_begins_with(name, prefix) do
    fn
      {_, atts, _} ->
        Enum.find(atts, false, fn
          {^name, value} ->
            String.starts_with?(value, prefix)

          _ ->
            false
        end)

      _ ->
        false
    end
  end

  @doc """
  Creates a matcher that matches every matcher in the list of `selectors`.

      iex> import Traverse.Matcher
      iex> Traverse.parse(~s(<html><head id="5" class /><body id="5" class>))
      ...> |> Traverse.Matcher.query_all(matches_all([
      ...>   element_name_is("body"),
      ...>   id_is("5"),
      ...>   contains_attribute("class")
      ...> ]))
      [{"body", [{"id", "5"}, {"class", "class"}], []}]
  """
  def matches_all(selectors) do
    fn node -> Enum.all?(selectors, & &1.(node)) end
  end

  @doc """
  Creates a matcher that matches any matcher in the list of `selectors`.

      iex> import Traverse.Matcher
      iex> Traverse.parse(~s(<html><header /><div class="header" />))
      ...> |> Traverse.Matcher.query_all(matches_any([
      ...>   element_name_is("header"),
      ...>   "class" |> attribute_is("header")
      ...> ]))
      [
        {"header", [], []},
        {"div", [{"class", "header"}], []}
      ]
  """
  def matches_any(selectors) do
    fn node -> Enum.any?(selectors, & &1.(node)) end
  end

  @doc """
  Creates a matcher that matches a node that has any attribute whith `name`.

      iex> Traverse.parse(~s(<html><body class="something"))
      ...> |> Traverse.Matcher.query(Traverse.Matcher.contains_attribute("class"))
      {"body", [{"class", "something"}], []}
  """
  @spec contains_attribute(String.t()) :: matcher
  def contains_attribute(name) do
    fn
      {_, [], _children} ->
        false

      {_, attributes, _children} when is_list(attributes) ->
        Enum.find(attributes, fn
          {^name, _value} ->
            true

          _ ->
            false
        end)

      _ ->
        false
    end
  end

  @doc """
  Matches all text nodes.

      iex> import Traverse.Matcher
      iex> Traverse.parse(\"\"\"
      ...> <html>
      ...>   <div>Hello</div>
      ...>   <div><em>There</em></div>
      ...> \"\"\")
      ...> |> query_all(is_text_element())
      ["Hello", "There"]
  """
  def is_text_element do
    fn
      content when is_binary(content) -> true
      _ -> false
    end
  end

  @doc """
  Matches elements whose `class` attribute is exactly `class`.
  """
  def class_name_is(class) do
    attribute_is("class", class)
  end

  @doc """
  Matches elements with a class attribute that contains the `class`.

      iex> ~s[<html><div class="class-a class-b class-c">Hello</div>]
      ...> |> Traverse.query(Traverse.Matcher.has_class_name("class-b"))
      {"div", [{"class", "class-a class-b class-c"}], ["Hello"]}
  """
  def has_class_name(class) do
    fn
      {_element, atts, _children} ->
        Enum.any?(atts, fn
          {"class", value} ->
            String.split(value, " ")
            |> Enum.any?(fn
              ^class -> true
              _ -> false
            end)

          _ ->
            false
        end)

      _ ->
        false
    end
  end
end
