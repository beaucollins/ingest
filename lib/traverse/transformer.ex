defmodule Traverse.Transformer do
  @doc """
  Build a transform based on a matcher and a transform function.

  The following is the equivalent of matching all nodes with `document.querySelectorAll('a[href^=/]')`
  and prefixing their `href` attributes with `http://example2.blog`.

      iex> ~s[<html><a href="/absolute-link">A Link</a>. <a href="http://example.blog">Full URI</a>.]
      ...> |> Traverse.parse()
      ...> |> Traverse.map(Traverse.Transformer.transform(
      ...>    Traverse.Matcher.and_matches(
      ...>      Traverse.Matcher.attribute_begins_with("href", "/"),
      ...>      Traverse.Matcher.element_name_is("a")
      ...>    ),
      ...>    Traverse.Transformer.replace_attribute("href", &("http://example2.blog" <> &1))
      ...> ))
      ...> |> Traverse.Document.to_string()
      ~s[<html><a href="http://example2.blog/absolute-link">A Link</a>. <a href="http://example.blog">Full URI</a>.</html>]

  """
  def transform(matcher, transformer, otherwise \\ unchanged()) do
    fn
      node ->
        case matcher.(node) do
          true ->
            transformer.(node)

          false ->
            otherwise.(node)
        end
    end
  end

  def transform_all_elements(do: transformer) do
    transform(
      fn
        {_element, _atts, _children} ->
          true

        _ ->
          false
      end,
      transformer
    )
  end

  @doc """
  A transformer that replaces an HTML node with its children.

  Find all `<div>`'s and output only their children's HTML content:

      iex> ~s[<div><p>Paragraph 1.</p><p>Paragraph 2</p><hr>]
      ...> |> Traverse.parse()
      ...> |> Traverse.map(
      ...>      Traverse.Transformer.transform(
      ...>        Traverse.Matcher.element_name_is("div"),
      ...>        Traverse.Transformer.select_children()
      ...>     )
      ...>   )
      ...> |> Traverse.Document.to_string()
      "<p>Paragraph 1.</p><p>Paragraph 2</p><hr />"

  """
  def select_children() do
    fn
      fragment ->
        case fragment do
          {_name, _atts, children} ->
            children

          _ ->
            fragment
        end
    end
  end

  def remove_content() do
    fn
      _fragment -> []
    end
  end

  def replace_attribute(key, transformer) do
    fn
      {type, atts, children} ->
        {type,
         Enum.map(atts, fn
           {^key, value} -> {key, transformer.(value)}
           other -> other
         end), children}

      fragment ->
        fragment
    end
  end

  def unchanged(), do: & &1

  def transform_first(transformers) when is_list(transformers) do
    fn
      node ->
        Enum.reduce(transformers, node, fn
          transformer, ^node ->
            transformer.(node)

          _, transformed ->
            transformed
        end)
    end
  end

  def map(document, mapper) do
    # Go through each node and allow the mapping function
    # to transform each document node

    map_fragment(document, mapper)
  end

  defp map_fragment({_element, _atts, _children} = node, mapper) do
    case mapper.(node) do
      {element, atts, children} ->
        {element, atts, List.flatten(map_fragment(children, mapper))}

      node ->
        map_fragment(node, mapper)
    end
  end

  defp map_fragment(fragment, mapper) when is_list(fragment) do
    Enum.map(fragment, fn
      node ->
        map_fragment(node, mapper)
    end)
  end

  defp map_fragment(fragment, mapper) when is_binary(fragment) do
    mapper.(fragment)
  end

  defp map_fragment({:comment, _} = comment, mapper) do
    mapper.(comment)
  end
end
