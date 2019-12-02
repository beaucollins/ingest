defmodule Simperium.JSONDiffTest do
  use ExUnit.Case, async: true
  import Simperium.JSONDiff

  doctest Simperium.JSONDiff

  describe "diff" do
    test "empty maps" do
      assert %{} == create_diff!(%{}, %{})
    end

    test "replace non-string, non-container values" do
      assert %{
               "A" => %{"o" => "r", "v" => 2},
               "B" => %{"o" => "r", "v" => false}
             } ==
               create_diff!(
                 %{
                   "A" => 1,
                   "B" => true
                 },
                 %{
                   "A" => 2,
                   "B" => false
                 }
               )
    end

    test "recursively diff objects" do
      source = %{"a" => false, "b" => 1}
      target = %{"b" => 2, "c" => true}

      assert %{"a" => %{"o" => "O", "v" => create_diff!(source, target)}} ==
               create_diff!(
                 %{"a" => source},
                 %{"a" => target}
               )
    end

    test "diff lists" do
      source = [1, 2]
      target = [1, 3]

      assert %{1 => %{"o" => "r", "v" => 3}} = create_diff!(source, target)
    end

    test "diff lists common prefix and suffix" do
      source = [1, 3, 4, 5]
      target = [1, 2, 3, 4, 5]

      assert %{1 => %{"o" => "+", "v" => 2}} = create_diff!(source, target)
    end

    test "diff lists no prefix" do
      source = [3, 4, 5]
      target = [2, 3, 4, 5]

      assert %{0 => %{"o" => "+", "v" => 2}} = create_diff!(source, target)
    end
  end

  describe "apply_diff" do
    test ":error with :unknown_operation" do
      assert {:error, {:unknown_operation, "?", "a"}} ==
               apply_diff(%{"a" => %{"o" => "?"}, "b" => %{}}, %{})
    end

    test ":error with :invalid_operation" do
      assert {:error, {:invalid_operation, "lol", "b"}} ==
               apply_diff(%{"b" => "lol"}, %{})
    end

    test "empty diff" do
      assert {:ok, %{"a" => "b"}} == apply_diff(%{}, %{"a" => "b"})
    end

    test "apply diff" do
      a = %{
        "b" => [1, 3]
      }

      b = %{
        "a" => 1,
        "b" => [1, 2, 3]
      }

      patch = %{
        "a" => %{"o" => "+", "v" => 1},
        "b" => %{
          "o" => "L",
          "v" => %{
            1 => %{"o" => "+", "v" => 2}
          }
        }
      }

      assert {:ok, b} == apply_diff(patch, a)
    end

    test "apply list diff" do
      a = [1, "a", 3]
      b = [1, "ab", 2, 3]

      patch = %{
        1 => %{"o" => "d", "v" => "=1\t+b"},
        2 => %{"o" => "+", "v" => 2}
      }

      assert {:ok, b} == apply_diff(patch, a)
    end

    test "apply list replace" do
      a = [1, 1, 0, 3]
      b = [1, 2, 3]

      patch = %{
        1 => %{"o" => "r", "v" => 2},
        2 => %{"o" => "-"}
      }

      assert {:ok, b} == apply_diff(patch, a)
    end

    test "apply list diff with objec diff" do
      a = [%{}]
      b = [%{"a" => "b"}]

      patch = %{
        0 => %{
          "o" => "O",
          "v" => %{
            "a" => %{"o" => "+", "v" => "b"}
          }
        }
      }

      assert {:ok, b} == apply_diff(patch, a)
    end

    test "apply list diff with list diff" do
      a = [1, [1, 2], 3]
      b = [1, [], 3]

      patch = %{
        1 => %{
          "o" => "L",
          "v" => %{
            0 => %{"o" => "-"},
            1 => %{"o" => "-"}
          }
        }
      }

      assert {:ok, b} == apply_diff(patch, a)
    end
  end

  test "diff strings with emoji" do
    {:ok, diff} = create_diff("❤️ SimperiumEx 🚀 Launch", "❤️ SimperiumEx Launch")

    assert "=15\t-3\t=6" == diff
    assert "❤️ SimperiumEx Launch" == apply_diff!(diff, "❤️ SimperiumEx 🚀 Launch")
  end

  test "diff strings with emoji2" do
    {:ok, diff} = create_diff(
      "Hello SimperiumEx\n\nTime to 🚀\n\nI ❤️ Simperium\n\n",
      "Hello"
    )

    assert "=5\t-42" = diff
    assert "Hello" = apply_diff!("=5\t-42", "Hello SimperiumEx\n\nTime to 🚀\n\nI ❤️ Simperium\n\n")
  end
end
