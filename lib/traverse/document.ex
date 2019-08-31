defmodule Traverse.Document do
  @moduledoc """
  Utilities for traversing a DOM from `:mochiweb_html.parse/1`.
  """

  @doc """
  Find DOM elements that return true for the given matcher.

  Find all nodes that have`id="two"`

      iex> :mochiweb_html.parse(~s(<html><body><div /><div id="two">Hello</div>))
      ...> |> Traverse.Document.find_element(Traverse.Matcher.id_is("two"))
      [{"div", [{"id", "two"}], ["Hello"]}]

  Find all nodes that are `<span>` elements:

      iex> :mochiweb_html.parse(~s(<html><body><span>1</span><span>2</span><div><span>3</span></html>))
      ...> |> Traverse.Document.find_element(Traverse.Matcher.element_name_is("span"))
      [{"span", [], ["3"]}, {"span", [], ["2"]}, {"span", [], ["1"]}]

  Find all nodes that are `<span>` elements and have a `class="important"` attribute:

      iex> import Traverse.Matcher
      iex> :mochiweb_html.parse(~s(
      ...>   <html>
      ...>     <span>Not important</span>
      ...>     <span class="important">Important</span>
      ...>     <div class="important"/>
      ...> ))
      ...> |> Traverse.Document.find_element(
      ...>     attribute_is("class", "important")
      ...>     |> and_matches(element_name_is("span"))
      ...> )
      [{"span", [{"class", "important"}], ["Important"]}]
  """
  @spec find_element(:mochiweb_html.html_node(), Matcher.matcher()) :: [
          :mochiweb_html.html_node()
        ]
  def find_element(node, matcher) do
    Traverse.Matcher.find(node, matcher)
  end

  @doc """
  Given a fragment, returns the text content of the DOM node.

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

      iex> :mochiweb_html.parse("<html><body><div>")
      ...> |> Traverse.Document.node_content()
      ""

  """
  def node_content(fragment)

  def node_content(fragment) when is_binary(fragment) do
    fragment |> String.trim()
  end

  def node_content(fragment) when is_list(fragment) do
    Enum.reduce(
      fragment,
      "",
      &(case &2 do
          "" -> ""
          preceding -> preceding <> "\n"
        end <> node_content(&1))
    )
  end

  def node_content({_type, _attributes, children} = _node) do
    node_content(children)
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
end
