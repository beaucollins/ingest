defmodule Traverse.Matcher do
  @moduledoc """
  Functions for querying a DOM or DOM fragment.
  """
  @type matcher :: (:mochiweb_html.html_node() -> boolean)

  @doc """
  Returns a matcher for a given element type.

      iex> import Traverse.Matcher
      iex> ~s(
      ...>   <html>
      ...>     <head>
      ...>       <title>Cool beans</title>
      ...>     </head>
      ...>     <body>
      ...> )
      ...> |> Traverse.query_all(element_name_is("title"))
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
      iex> ~s(
      ...>   <html>
      ...>     <head>
      ...>       <title>Cool beans</title>
      ...>     </head>
      ...>     <body id="post-22">Stuff
      ...> )
      ...> |> Traverse.query_all(
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
      iex> ~s(<html><head><body><div id="post-5"/><span>)
      ...> |> Traverse.query_all(
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

      iex> ~s(<html><div id="me">Hi.)
      ...> |> Traverse.query(Traverse.Matcher.id_is("me"))
      {"div", [{"id", "me"}], ["Hi."]}
  """
  @spec id_is(String.t()) :: matcher
  def id_is(id), do: attribute_is("id", id)

  @doc """
  Creates a matcher that matches nodes with an attribute of `name`
  that matches the given `value`.

      iex> ~s(<html><body class="special")
      ...> |> Traverse.query(Traverse.Matcher.attribute_is("class", "special"))
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
      iex> ~s(<html><head id="5" class /><body id="5" class>)
      ...> |> Traverse.query_all(matches_all([
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
      iex> ~s(<html><header /><div class="header" />)
      ...> |> Traverse.query_all(matches_any([
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

      iex> ~s(<html><body class="something")
      ...> |> Traverse.query(Traverse.Matcher.contains_attribute("class"))
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
      iex> \"\"\"
      ...> <html>
      ...>   <div>Hello</div>
      ...>   <div><em>There</em></div>
      ...> \"\"\"
      ...> |> Traverse.query_all(is_text_element())
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
