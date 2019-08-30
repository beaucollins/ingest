defmodule Traverse.Document do
  @moduledoc """
  Utilities for traversing a DOM from `:mochiweb_html.parse/1`.
  """

  @doc """
  Find DOM elements that return true for the given matcher.

  Find all nodes that have`id="two"`

      iex> :mochiweb_html.parse("<html><body><div /><div id=\\"two\\">Hello</div>")
      ...> |> Traverse.Document.find_element(Traverse.Matcher.id_is("two"))
      [{"div", [{"id", "two"}], ["Hello"]}]

  Find all nodes that are `<span>` elements:

      iex> :mochiweb_html.parse("<html><body><span>1</span><span>2</span><div><span>3</span></html>")
      ...> |> Traverse.Document.find_element(Traverse.Matcher.element_name_is("span"))
      [{"span", [], ["3"]}, {"span", [], ["2"]}, {"span", [], ["1"]}]

  Find all nodes that are `<span>` elements and have a `class="important"` attribute:

      iex> import Traverse.Matcher
      iex> :mochiweb_html.parse(\"\"\"
      ...>   <html>
      ...>     <span>Not important</span>
      ...>     <span class="important">Important</span>
      ...>     <div class="important"/>
      ...> \"\"\")
      ...> |> Traverse.Document.find_element(
      ...>     attribute_is("class", "important")
      ...>     |> and_matches(element_name_is("span"))
      ...> )
      [{"span", [{"class", "important"}], ["Important"]}]
  """
  @spec find_element(:mochiweb_html.html_node(), Matcher.matcher) :: [:mochiweb_html.html_node()]
  def find_element(node, matcher) do
    Traverse.Matcher.find(node, matcher)
  end

  def node_content(fragment, defaultTo \\ "")

  def node_content(fragment, defaultTo) when is_list(fragment) do
    Enum.map(fragment, &node_content(&1, defaultTo))
  end

  def node_content({_type, _attributes, children}, defaultTo) do
    case children do
      [] -> defaultTo
      _ -> Enum.reduce(children, &(&1 <> "\n" <> &2))
    end
  end

  def attribute({_type, attributes, _children}, name, defaultTo \\ nil) do
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
