defmodule Simperium.DiffMatchPatchTest do
  use ExUnit.Case, async: true
  import Simperium.DiffMatchPatch

  doctest Simperium.DiffMatchPatch


  test "diff_main" do
    assert  [eq: ["a", "b"], del: ["c"], ins: ["d"], eq: ["e", "f"]] == diff_main("abcef", "abdef") |> diff_cleanup_efficiency()
  end

  test "diff_main unicode points" do
    assert [eq: ["a"], del: ["🖖🏿"], ins: ["🖖"], eq: ["c"]] == diff_main("a🖖🏿c", "a🖖c")
  end

  test "diff_to_delta" do
    assert "=2\t-1\t=1\t+ef" == "abcd" |> diff_main("abdef") |> diff_to_delta()
  end

  test "diff_to_delta tabs" do
    assert "=5\t+%09e" == "ab\tcd" |> diff_main("ab\tcd\te") |> diff_to_delta()
  end

  test "deltas with special characters" do
    assert "=5\t-5\t+%DA%82 %5C %7C" ==
             [
               {:eq, String.codepoints("\u0680 \t %")},
               {:del, String.codepoints("\u0681 \n ^")},
               {:ins, String.codepoints("\u0682 \\ |")}
             ]
             |> diff_to_delta()
  end

  test "diff_from_delta" do
    diffs = [
      {:eq, "jump"},
      {:del, "s"},
      {:ins, "ed"},
      {:eq, " over "},
      {:del, "the"},
      {:ins, "a"},
      {:eq, " lazy"},
      {:ins, "old dog"}
    ] |> Enum.map(fn {op, str} -> { op, String.codepoints(str) } end)
    assert diffs === "jumps over the lazy" |> diff_from_delta(diffs |> diff_to_delta())
  end
end
