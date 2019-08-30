defmodule Ingest.Traverse do
  @moduledoc """
  Utilities for traversing a DOM from :mochiweb_html.parse/1.
  """

  @doc """
  Find DOM elements that return true for the given matcher.

  Find all nodes that have`id="two"`

      iex> :mochiweb_html.parse("<html><body><div /><div id=\\"two\\">Hello</div>")
      ...> |> Ingest.Traverse.find_element(Ingest.Traverse.id_is("two"))
      [{"div", [{"id", "two"}], ["Hello"]}]

  Find all nodes that are `<span>` elements:

      iex> :mochiweb_html.parse("<html><body><span>1</span><span>2</span><div><span>3</span></html>")
      ...> |> Ingest.Traverse.find_element(Ingest.Traverse.element_name_is("span"))
      [{"span", [], ["3"]}, {"span", [], ["2"]}, {"span", [], ["1"]}]

  Find all nodes that are `<span>` elements and have a `class="important"` attribute:

      iex> :mochiweb_html.parse(\"\"\"
      ...>   <html>
      ...>     <span>Not important</span>
      ...>     <span class="important">Important</span>
      ...>     <div class="important"/>
      ...> \"\"\")
      ...> |> Ingest.Traverse.find_element(
      ...>     Ingest.Traverse.attribute_is("class", "important")
      ...>     |> Ingest.Traverse.and_matches(Ingest.Traverse.element_name_is("span"))
      ...> )
      [{"span", [{"class", "important"}], ["Important"]}]
  """
  def find_element(node, matcher, acc \\ [])

  def find_element(fragment, matcher, acc) when is_list(fragment) do
    Enum.reduce(fragment, acc, fn
      node = {_element, _attributes, children}, matches ->
        find_element(
          children,
          matcher,
          if matcher.(node) do
            [node | matches]
          else
            matches
          end
        )

      _, matches ->
        matches
    end)
  end

  def find_element(node = {_element, _attributes, _children}, matcher, acc) do
    find_element([node], matcher, acc)
  end

  def element_name_is(name) do
    fn
      {element, _attributes, _children} when element == name ->
        true

      _ ->
        false
    end
  end

  def and_matches(fn1, fn2) do
    fn value -> fn1.(value) && fn2.(value) end
  end

  def id_is(elementID) do
    attribute_is("id", elementID)
  end

  def attribute_is(attributeName, attributeValue) do
    fn
      {_, atts, _} ->
        Enum.find(atts, fn
          {name, value} when attributeName == name and attributeValue == value -> true
          _ -> false
        end)
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

  def contains_attribute(attributeName) do
    fn
      {_, [], _children} ->
        false

      {_, attributes, _children} when is_list(attributes) ->
        Enum.find(attributes, fn
          {name, _value} when name == attributeName ->
            true

          _ ->
            false
        end)

      _ ->
        false
    end
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
end
