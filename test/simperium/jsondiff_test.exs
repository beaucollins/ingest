defmodule Simperium.JSONDiffTest do
  use ExUnit.Case
  import Simperium.JSONDiff

  doctest Simperium.JSONDiff

  describe "diff" do
    test "empty maps" do
      assert %{} == diff(%{}, %{})
    end

    test "replace non-string, non-container values" do
      assert %{
               "A" => %{"o" => "r", "v" => 2},
               "B" => %{"o" => "r", "v" => false}
             } ==
               diff(
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

      assert %{"a" => %{"o" => "O", "v" => diff(source, target)}} ==
               diff(
                 %{"a" => source},
                 %{"a" => target}
               )
    end

    test "diff lists" do
      source = [1, 2]
      target = [1, 3]

      assert %{1 => %{"o" => "r", "v" => 3}} = diff(source, target)
    end

    test "diff lists common prefix and suffix" do
      source = [1, 3, 4, 5]
      target = [1, 2, 3, 4, 5]

      assert %{1 => %{"o" => "+", "v" => 2}} = diff(source, target)
    end

    test "diff lists no prefix" do
      source = [3, 4, 5]
      target = [2, 3, 4, 5]

      assert %{0 => %{"o" => "+", "v" => 2}} = diff(source, target)
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
  end
end
