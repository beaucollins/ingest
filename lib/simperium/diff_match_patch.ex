defmodule Simperium.DiffMatchPatch do
  @moduledoc """
  DiffMatchPatch compatible operations needed to perform JSONDiff sync operations.

  This is not a complete implementation of the `diff-match-patch` API. Not all functions
  are needed to implement JSONDiff.
  """
  @doc """
  Produces the `myers_difference` operations of two strings.

      iex> diff_main( "abc", "abbc")
      [{:eq, "ab"}, {:ins, "b"}, {:eq, "c"}]

  See `List.myers_difference/3`.
  """
  def diff_main(text1, text2) do
    String.myers_difference(text1, text2)
  end

  @doc """
  Currently not implemented. Returns the diffs as is.

  Optimizes by reducing the total number of change operations.
  """
  def diff_cleanup_efficiency(diffs) do
    diffs
  end

  @doc """
  Converts a list of diffs (output of `diff_main/2`) into a lossy*, tab-delimited, string
  representation of the diff.

      iex> diff_main("the quick brown fox", "the quiet green foxes")
      ...> |> diff_to_delta()
      "=7\t-2\t+et\t=1\t-1\t+g\t=1\t-2\t+ee\t=5\t+es"

  *Lossy due to converting `:del` and `:eq` operations into their length counts. For example: `{:eq, "something"}` becomes `=9`.

  """
  def diff_to_delta(diffs) do
    Enum.reduce(diffs, "", fn op, acc ->
      acc <>
        if acc === "" do
          ""
        else
          "\t"
        end <>
        case op do
          {:eq, chars} ->
            "=" <> (chars |> String.length() |> to_string())

          {:del, chars} ->
            "-" <> (chars |> String.length() |> to_string())

          {:ins, chars} ->
            "+" <> (chars |> to_string() |> URI.encode() |> String.replace("%20", " "))
        end
    end)
  end

  @doc """
  Given a source text and a delta (see `diff_to_delta/1`) produces the diff list
  that can be used with the source text.

      iex> diff_from_delta("goodbye", "-2\t=5\t+hello")
      [
        {:del, "go"},
        {:eq, "odbye"},
        {:ins, "hello"}
      ]
  """
  def diff_from_delta(source, delta) do
    reduce_delta(source, delta, [], fn op, ops ->
      [op | ops]
    end)
    |> Enum.reverse()
  end

  @doc """
  Given a `delta` (`diff_to_delta/1`) and a source text `source`, produces the
  new text.

      iex> apply_diff_from_delta("hello world", "=6\t-5\t+kansas")
      {:ok, "hello kansas"}
  """
  def apply_diff_from_delta(source, delta) do
    {:ok,
     reduce_delta(source, delta, "", fn op, output ->
       case op do
         {:ins, chars} -> output <> to_string(chars)
         {:eq, chars} -> output <> to_string(chars)
         {:del, _} -> output
       end
     end)}
  end

  defp token_as_operation(token) do
    op = String.slice(token, 0, 1)
    rest = String.slice(token, 1..-1)

    case op do
      "+" -> {:+, rest}
      "-" -> {:-, String.to_integer(rest)}
      "=" -> {:=, String.to_integer(rest)}
    end
  end

  defp reduce_delta(source, delta, acc, fun) do
    {_remainder, output} =
      delta
      |> String.split("\t")
      |> Stream.map(&token_as_operation/1)
      |> Enum.reduce({source, acc}, fn op, {source, output} ->
        case op do
          {:-, count} ->
            {String.slice(source, count..-1),
             fun.({:del, String.slice(source, 0..(count - 1))}, output)}

          {:=, count} ->
            {String.slice(source, count..-1),
             fun.({:eq, String.slice(source, 0..(count - 1))}, output)}

          {:+, chars} ->
            {source, fun.({:ins, chars}, output)}
        end
      end)

    output
  end
end
