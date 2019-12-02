defmodule TraverseTest do
  use ExUnit.Case, async: true

  doctest Traverse

  test "map with comments" do
    mapped =
      """
        <body>
        <!--This is a comment-->
      """
      |> Traverse.parse()
      |> Traverse.map(fn
        {:comment, content} ->
          {"p", [], [content]}

        node ->
          node
      end)
      |> Traverse.Document.to_string()

    assert mapped === "<body><p>This is a comment</p></body>"
  end
end
