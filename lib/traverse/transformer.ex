defmodule Traverse.Transformer do

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

  def transform_all_elements(transformer) do
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

  def select_children() do
    fn
      fragment ->
        case fragment do
          {_name, _atts, children} ->
            children
          _ -> fragment
        end
      end
  end

  def remove_content() do
    fn
      _fragment -> []
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
    |> Traverse.Document.to_string()
  end

  defp map_fragment({_element, _atts, _children} = node, mapper) do
    case mapper.(node) do
      {element, atts, children} ->
        {element, atts, map_fragment(children, mapper)}
      node -> map_fragment(node, mapper)
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
