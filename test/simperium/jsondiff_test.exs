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
  end
end
