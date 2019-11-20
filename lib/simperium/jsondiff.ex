defmodule Simperium.JSONDiff do
  @moduledoc """
  Create, apply, and transform JSONDiff constructs.

  What is a JSONDiff? I recipe for transforming one JSON compatible
  source datastructure into a desired result. It is the delta between
  two JSON objects.

  Example. Given JSON of `{"note": "hello"}` and `{"note": "hello world"}`
  the delta in plain English could be described as:

  > Append the string `" world"` to the value at key `"note"`.

  In JSONDiff that looks like:

  ```json
  {"note": { "o": "d", "v": "=5\t+ world"}}
  ```

  To compute this diff using `Jason` as our encoder/decoder:

      iex> ~s({"note": "hello"})
      ...> |> Jason.decode!()
      ...> |> create_diff!(Jason.decode!(~s({"note": "hello world"})))
      ...> |> Jason.encode!()
      ~s({"note":{"o":"d","v":"=5\\\\t+ world"}})

  The output of `create_diff` can be used with the `source` and `apply_diff`
  to transform at JSON of the same value of `source` to the desired `target`.

      iex> ~s({"note":{"o":"d","v":"=5\\\\t+ world"}})
      ...> |> Jason.decode!()
      ...> |> apply_diff!(Jason.decode!(~s({"note": "hello"})))
      ...> |> Jason.encode!()
      ~s({"note":"hello world"})

  """

  @doc """
  Returns the diff from a successful `create_diff/2` otherwise throws.

      iex> create_diff!(%{}, %{"a" => 1})
      %{"a" => %{"o" => "+", "v" => 1}}

  """
  def create_diff!(source, target) do
    case create_diff(source, target) do
      {:ok, diff} -> diff
      _ -> raise Simperium.JSONDiff.InvalidDiffError
    end
  end

  @doc """
  Produce the delta describing the changes to make `source` into `target`.

  Keys present in `source` but absent in `target` are removed:

      iex> create_diff(%{"x" => 1}, %{})
      {:ok, %{"x" => %{"o" => "-"}}}

  Keys absent in `source` but present in `target` are added:

      iex> create_diff(%{}, %{"b" => 2})
      {:ok, %{"b" => %{"o" => "+", "v" => 2}}}

  Keys present in both `source` and `target` both are diffed:

      iex> create_diff(%{"a" => 1}, %{"a" => 2})
      {:ok, %{"a" => %{"o" => "r", "v" => 2}}}

  Lists are reduced to change operations:

      iex> create_diff(%{"a" => [1, true, "b", "c"]}, %{"a" => [1, false, "bd", "c"]})
      {:ok, %{
        "a" => %{
          "o" => "L",
          "v" => %{
            1 => %{ "o" => "r", "v" => false },
            2 => %{ "o" => "d", "v" => "=1\t+d"}
          }
        }
      }}

  String values use diff-match-patch:

      iex> create_diff(%{"a" => "hello world"}, %{"a" => "good bye"})
      {:ok, %{"a" => %{"o" => "d", "v" => "-4\t+g\t=1\t-2\t=1\t-2\t=1\t+ bye"}}}


  Equal objects return empty diffs:

      iex> create_diff(%{"a" => "b"}, %{"a" => "b"})
      {:ok, %{}}

  """

  def create_diff(source, target) when source == target do
    {:ok, %{}}
  end

  def create_diff(source, target) when is_binary(source) and is_binary(target) do
    {:ok,
     Simperium.DiffMatchPatch.diff_main(source, target)
     |> Simperium.DiffMatchPatch.diff_to_delta()}
  end

  def create_diff(source, target) when is_map(source) and is_map(target) do
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
          {:ok, {operation, value}} -> Map.put(diffs, key, %{"o" => operation, "v" => value})
          {:ok, :=} -> diffs
          {:ok, _} -> diffs
          error = {:error, _} -> error
        end
      end)

    {:ok, diffs}
  end

  def create_diff(source, target) when is_list(source) and is_list(target) do
    {prefix, source_slice, target_slice} = compare_lists(source, target)

    diff =
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
          {:halt, _} -> {:ok, {"+", target}}
          {_, :halt} -> {:ok, "-"}
          {source, target} when source == target -> {:ok, :=}
          _ -> diff_key_operation(source, target)
        end
        |> case do
          {:ok, :=} ->
            diffs

          {:ok, "-"} ->
            Map.put(diffs, index + prefix, %{"o" => "-"})

          {:ok, {operation, value}} ->
            Map.put(diffs, index + prefix, %{"o" => operation, "v" => value})
        end
      end)

    {:ok, diff}
  end

  @doc """
  Returns result of applying patch to source otherwise throws.

      iex> apply_diff!(%{"a" => %{"o" => "-"}}, %{"a" => "hello"})
      %{}

      iex> apply_diff!(%{"a" => %{"o" => "?"}}, %{})
      ** (Simperium.JSONDiff.InvalidPatchError) Invalid patch

  See `apply_diff/2`
  """
  def apply_diff!(patch, source) do
    case apply_diff(patch, source) do
      {:error, _} -> raise Simperium.JSONDiff.InvalidPatchError
      {:ok, result} -> result
    end
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

  def apply_diff(patch, source) do
    {:error, :invalid_diff, patch, source}
  end

  defp diff_key_operation(source, target) when source == target, do: {:ok, :=}

  defp diff_key_operation(source, target)
       when is_map(source) and is_map(target) do
    with {:ok, diff} <- create_diff(source, target),
         do: {:ok, {"O", diff}}
  end

  defp diff_key_operation(source, target)
       when is_list(source) and is_list(target) do
    with {:ok, diff} <- create_diff(source, target),
         do: {:ok, {"L", diff}}
  end

  defp diff_key_operation(source, target) when is_binary(source) and is_binary(target) do
    with {:ok, diff} <- create_diff(source, target),
         do: {:ok, {"d", diff}}
  end

  # Not equal, not containers, just replace
  defp diff_key_operation(_source, target) do
    {:ok, {"r", target}}
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

defmodule Simperium.JSONDiff.InvalidDiffError do
  defexception message: "Invalid diff"
end

defmodule Simperium.JSONDiff.InvalidPatchError do
  defexception message: "Invalid patch"
end
