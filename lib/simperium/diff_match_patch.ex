defmodule Simperium.DiffMatchPatch do
  @doc """
  Produces the `myers_difference` operations of two strings.

      iex> Simperium.DiffMatchPatch.diff_main( "abc", "abbc")
      [{:eq, ["a", "b"]}, {:ins, ["b"]}, {:eq, ["c"]}]

  See `List.myers_difference/3`.
  """
  def diff_main(text1, text2) do
    List.myers_difference(String.graphemes(text1), String.graphemes(text2))
  end

  @doc """
  Currently not implemented. Returns the diffs as is.

  Optimizes by reducing the total number of change operations.
  """
  def diff_cleanup_efficiency(diffs) do
    diffs
  end

  @doc """
  Converts a list of diffs (output of `Simperium.DiffMatchPatch.diff_main/2`) into a lossy string
  representation of the diff.

      iex> Simperium.DiffMatchPatch.diff_main( "the quick brown fox", "the quiet green foxes")
      ...> |> Simperium.DiffMatchPatch.diff_to_delta()
      "=7\t-2\t+et\t=1\t-1\t+g\t=1\t-2\t+ee\t=5\t+es"

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
            "=" <> (length(chars) |> to_string())

          {:del, chars} ->
            "-" <> (length(chars) |> to_string())

          {:ins, chars} ->
            "+" <> (chars |> to_string() |> URI.encode() |> String.replace("%20", " "))
        end
    end)
  end

  def diff_from_delta(delta) do
  end
end
