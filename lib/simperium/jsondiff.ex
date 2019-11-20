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
    {prefix, source_slice, target_slice} = compare_lists(source, target)

    Stream.zip(
      Stream.concat(source_slice, Stream.cycle([:halt])),
      Stream.concat(target_slice, Stream.cycle([:halt]))
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
        "-" -> Map.put(diffs, index + prefix, %{"o" => "-"})
        {operation, value} -> Map.put(diffs, index + prefix, %{"o" => operation, "v" => value})
      end
    end)
  end

  @doc """
  Given a `patch` (see `diff/2`) and a `source` object, produces the new
  state of the object with the patch applied.

  Add a key/value pair to a `Map`:

      iex> %{"a" => %{"o" => "+", "v" => 1}}
      ...> |> apply_diff(%{"b" => 2})
      {:ok, %{"a" => 1, "b" => 2}}

  Remove a key/value pair to a `Map`:

      iex> %{"a" => %{"o" => "-"}}
      ...> |> apply_diff(%{"a" => 1, "b" => 2})
      {:ok, %{"b" => 2}}

  Replace a key/value pair in a `Map`:

      iex> %{"a" => %{"o" => "r", "v" => "abc"}}
      ...> |> apply_diff(%{"a" => 123})
      {:ok, %{"a" => "abc"}}

  Apply diff to key value in a `Map`:

      iex> %{"a" => %{"o" => "d", "v" => "-5\t+goodbye\t=6"}}
      ...> |> apply_diff(%{"a" => "hello world"})
      {:ok, %{"a" => "goodbye world"}}

  Recursively apply diff to `Map` at key:

      iex> %{"a" => %{"o" => "O", "v" => %{
      ...>   "thing" => %{ "o" => "d", "v" => "=6\t-5\t+new york" }
      ...> }}}
      ...> |> apply_diff(%{"a" => %{"thing" => "hello world"}})
      {:ok, %{"a" => %{"thing" => "hello new york"}}}
  """
  def apply_diff(patch, source)

  def apply_diff(patch, source) when is_map(source) and is_map(patch) do
    Enum.reduce(patch, {:ok, source}, fn
      _op, res = {:error, _reason} ->
        res

      {key, %{"o" => "+", "v" => value}}, {:ok, target} ->
        case Map.has_key?(source, key) do
          false -> {:ok, Map.put(target, key, value)}
          true -> {:error, {:key_exists, key}}
        end

      {key, %{"o" => "-"}}, {:ok, target} ->
        case Map.has_key?(source, key) do
          true -> {:ok, Map.delete(target, key)}
          false -> {:error, {:key_missing, key}}
        end

      {key, %{"o" => "r", "v" => value}}, {:ok, target} ->
        case Map.has_key?(source, key) do
          true -> {:ok, Map.put(target, key, value)}
          false -> {:error, {:key_missing, key}}
        end

      {key, %{"o" => "d", "v" => value}}, {:ok, target} ->
        case Map.get(source, key) do
          original when is_binary(original) ->
            case apply_diff(value, original) do
              {:ok, updated} -> {:ok, Map.put(target, key, updated)}
            end

          _ ->
            {:error, {:invalid_source, key}}
        end

      {key, %{"o" => "O", "v" => object_diff}}, {:ok, target} ->
        case(apply_diff(object_diff, Map.get(source, key))) do
          {:ok, updated} -> {:ok, Map.put(target, key, updated)}
          result -> result
        end

      {key, %{"o" => "L", "v" => list_diff}}, {:ok, target} ->
        case apply_diff(list_diff, Map.get(source, key)) do
          {:ok, updated} -> {:ok, Map.put(target, key, updated)}
          result -> result
        end

      {key, %{"o" => operation}}, {:ok, _target} ->
        {:error, {:unknown_operation, operation, key}}

      {key, value}, {:ok, _target} ->
        {:error, {:invalid_operation, value, key}}
    end)
  end

  def apply_diff(patch, source) when is_list(source) and is_map(patch) do
    Enum.reduce(patch, {:ok, source, 0}, fn
      _key_value, error = {:error, _reason} ->
        error

      {key, %{"o" => "-"}}, {:ok, target, removals} ->
        {:ok, List.delete_at(target, key - removals), removals + 1}

      {key, %{"o" => "+", "v" => value}}, {:ok, target, removals} ->
        {:ok, List.insert_at(target, key - removals, value), removals}

      {key, %{"o" => "r", "v" => value}}, {:ok, target, removals} ->
        {:ok, List.replace_at(target, key - removals, value), removals}

      {key, %{"o" => "d", "v" => patch}}, {:ok, target, removals} ->
        case Enum.fetch(source, key) do
          {:ok, current} ->
            case apply_diff(patch, current) do
              {:ok, updated} -> {:ok, List.replace_at(target, key - removals, updated), removals}
            end

          :error ->
            {:error, :invalid_patch, key}
        end

      {key, %{"o" => "L", "v" => patch}}, {:ok, target, removals} ->
        case Enum.fetch(source, key) do
          {:ok, current} ->
            case apply_diff(patch, current) do
              {:ok, list} -> {:ok, List.replace_at(target, key - removals, list), removals}
              {:error, reason} -> {:error, {:invalid_patch, key, reason}}
            end

          :error ->
            {:error, {:invalid_patch, key}}
        end

      {key, %{"o" => "O", "v" => patch}}, {:ok, target, removals} ->
        case Enum.fetch(source, key) do
          {:ok, current} ->
            case apply_diff(patch, current) do
              {:ok, updated} -> {:ok, List.replace_at(target, key + removals, updated), removals}
              {:error, reason} -> {:error, {:invalid_patch, key, reason}}
            end

          :error ->
            {:error, {:invalid_patch, key}}
        end

      {key, %{"o" => operation}}, {:ok, _target, _removals} ->
        {:error, {:unknown_operation, operation, key}}

      {key, patch}, {:ok, _target, _removals} ->
        {:error, {:invalid_diff, key, patch}}
    end)
    |> case do
      error = {:error, _reason} -> error
      {:ok, result, _removed} -> {:ok, result}
    end
  end

  def apply_diff(patch, source) when is_binary(patch) and is_binary(source) do
    {:ok, Simperium.DiffMatchPatch.apply_diff_from_delta(source, patch)}
  end

  def apply_diff(_patch, _source) do
    {:error, :invalid_diff}
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

  defp compare_lists(source, target) do
    prefix = compare_lists_prefix(source, target)

    suffix = compare_lists_prefix(Enum.reverse(source), Enum.reverse(target))

    slice = prefix..-(suffix + 1)

    {prefix, Enum.slice(source, slice), Enum.slice(target, slice)}
  end

  defp compare_lists_prefix(source, target) do
    Stream.zip(source, target)
    |> Stream.transform(0, fn
      {source, target}, acc when source != target ->
        {:halt, acc}

      {source, target}, acc when source == target ->
        {[acc + 1], acc + 1}
    end)
    |> Enum.reduce(0, fn i, _ -> i end)
  end
end
