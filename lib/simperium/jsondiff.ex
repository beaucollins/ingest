defmodule Simperium.JSONDiff do
  @doc """
  Produce the diff of two objects.

  Keys present in `source` but absent in `target` are removed:

      iex> diff(%{"x" => 1}, %{})
      %{"x" => %{"o" => "-"}}

  Keys absent in `source` but present in `target` are added:

      iex> diff(%{}, %{"b" => 2})
      %{"b" => %{"o" => "+", "v" => 2}}

  Keys present in both `source` and `target` both are diffed:

      iex> diff(%{"a" => 1}, %{"a" => 2})
      %{"a" => %{"o" => "r", "v" => 2}}

  Lists are reduced to change operations:

      iex> diff(%{"a" => [1, true, "b", "c"]}, %{"a" => [1, false, "bd", "c"]})
      %{
        "a" => %{
          "o" => "L",
          "v" => %{
            1 => %{ "o" => "r", "v" => false },
            2 => %{ "o" => "d", "v" => "=1\t+d"}
          }
        }
      }

  String values use diff-match-patch:

      iex> diff(%{"a" => "hello world"}, %{"a" => "good bye"})
      %{"a" => %{"o" => "d", "v" => "-4\t+g\t=1\t-2\t=1\t-2\t=1\t+ bye"}}


  Equal objects return empty diffs:

      iex> diff(%{"a" => "b"}, %{"a" => "b"})
      %{}

  """

  def diff(source, target) when source == target do
    %{}
  end

  def diff(source, target) when is_binary(source) and is_binary(target) do
    Simperium.DiffMatchPatch.diff_main(source, target)
    |> Simperium.DiffMatchPatch.diff_to_delta()
  end

  def diff(source, target) when is_map(source) and is_map(target) do
    keys_source = Map.keys(source) |> MapSet.new()
    keys_target = Map.keys(target) |> MapSet.new()

    keys_removed = MapSet.difference(keys_source, keys_target)
    keys_added = MapSet.difference(keys_target, keys_source)
    keys_replaced = MapSet.intersection(keys_source, keys_target)

    diffs =
      Enum.reduce(keys_removed, %{}, fn key, diffs ->
        Map.put(diffs, key, %{"o" => "-"})
      end)

    diffs =
      Enum.reduce(keys_added, diffs, fn key, diffs ->
        Map.put(diffs, key, %{"o" => "+", "v" => Map.get(target, key)})
      end)

    diffs =
      Enum.reduce(keys_replaced, diffs, fn key, diffs ->
        case diff_key_operation(Map.get(source, key), Map.get(target, key)) do
          {operation, value} -> Map.put(diffs, key, %{"o" => operation, "v" => value})
          := -> diffs
          _ -> diffs
        end
      end)

    diffs
  end

  def diff(source, target) when is_list(source) and is_list(target) do
    Stream.zip(
      Stream.concat(source, Stream.cycle([:halt])),
      Stream.concat(target, Stream.cycle([:halt]))
    )
    |> Stream.transform(nil, fn
      {:halt, :halt}, acc -> {:halt, acc}
      pair, acc -> {[pair], acc}
    end)
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{source, target}, index}, diffs ->
      case {source, target} do
        {:halt, _} -> {"+", target}
        {_, :halt} -> "-"
        {source, target} when source == target -> :=
        _ -> diff_key_operation(source, target)
      end
      |> case do
        := -> diffs
        "-" -> Map.put(diffs, index, %{"o" => "-"})
        {operation, value} -> Map.put(diffs, index, %{"o" => operation, "v" => value})
      end
    end)
  end

  defp diff_key_operation(source, target) when source == target, do: :=

  defp diff_key_operation(source, target)
       when is_map(source) and is_map(target) do
    {"O", diff(source, target)}
  end

  defp diff_key_operation(source, target)
       when is_list(source) and is_list(target) do
    {"L", diff(source, target)}
  end

  defp diff_key_operation(source, target) when is_binary(source) and is_binary(target) do
    {"d", diff(source, target)}
  end

  # Not equal, not containers, just replace
  defp diff_key_operation(_source, target) do
    {"r", target}
  end
end
