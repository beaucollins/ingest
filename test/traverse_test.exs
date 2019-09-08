defmodule TraverseTest do
  use ExUnit.Case

  doctest Traverse

  test "map with comments" do
    mapped = """
      <body>
      <!--This is a comment-->
    """
    |> Traverse.parse
    |> Traverse.map(fn
      { :comment, content } ->
        {"p", [], [content]}
      node -> node
    end)

    assert mapped === "<body><p>This is a comment</p></body>"
  end
end
