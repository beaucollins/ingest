defmodule Traverse.Matcher do
  @doc """
  Create a Matcher
  """
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
