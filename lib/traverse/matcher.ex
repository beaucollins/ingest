defmodule Traverse.Matcher do
  @type matcher :: (:mochiweb_html.html_node() -> boolean)

  def find(doc, matcher) do
    find_accumulated(doc, matcher, [])
  end

  defp find_accumulated(fragment, matcher, accumulated) when is_list(fragment) do
    Enum.reduce(fragment, accumulated, fn
      node = {_element, _attributes, children}, matches ->
        find_accumulated(
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

  defp find_accumulated(node, matcher, accumulated) do
    find_accumulated([node], matcher, accumulated)
  end

  @doc """
  Returns a matcher for a given element type.

      iex> import Traverse.Matcher
      iex> :mochiweb_html.parse(~s(
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
  Combines two matchers into a matcher that requires both to pass.

      iex> import Traverse.Matcher
      iex> :mochiweb_html.parse(~s(
      ...>   <html>
      ...>     <head>
      ...>       <title>Cool beans</title>
      ...>     </head>
      ...>     <body id="post-22">Stuff
      ...> ))
      ...> |> find(
      ...>   and_matches(
      ...>     element_name_is("body"),
      ...>     ("id" |> attribute_is("post-22"))
      ...>   )
      ...> )
      [{"body", [{"id", "post-22"}], ["Stuff\\n "]}]
  """
  @spec and_matches(matcher, matcher) :: matcher
  def and_matches(fn1, fn2) do
    fn value -> fn1.(value) && fn2.(value) end
  end

  @spec id_is(String.t()) :: matcher
  def id_is(elementID) do
    attribute_is("id", elementID)
  end

  @spec attribute_is(String.t(), String.t()) :: matcher
  def attribute_is(attributeName, attributeValue) do
    fn
      {_, atts, _} ->
        Enum.find(atts, fn
          {name, value} when attributeName == name and attributeValue == value -> true
          _ -> false
        end)
    end
  end

  @spec contains_attribute(String.t()) :: matcher
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
end
