defmodule Traverse.ExpTest do
  use ExUnit.Case

  alias Traverse.Document
  import Traverse.Matcher

  test "descendants" do
    # Trying to come up with the equivalent of
    # document.querySelector("div .thing")
    #
    # So first do a query all on "div" and then a query all on ".thing"
    document =
      Traverse.parse("""
        <html>
        <body>
          <div></div>
          <div class="thing"><span id="correct" class="thing"></div>
          <div><span id="incorrect"></div>
          <span id="incorrect" class="thing">
        </body>
      """)

    assert document
           |> stream(element_name_is("div"))
           |> Stream.flat_map(&stream_children(&1, "class" |> attribute_is("thing")))
           |> Enum.to_list() ===
             [{"span", [{"id", "correct"}, {"class", "thing"}], []}]
  end

  test "query children" do
    # given a Stream that produces Streams, iterate through
    result =
      """
        <html>
          <head><title>Hello World</title></head>
          <body>
            <div><span>1<span>x<span>y</span></span></span></div>
            <div><span>2</span></div>
            <div><span>3</span></div>
            <div><span>4</span></div>
            <span>5</span>
          </body>
      """
      |> Traverse.parse()
      |> stream(element_name_is("div"))
      |> Stream.flat_map(&stream_children(&1, element_name_is("span")))
      |> Stream.flat_map(&stream_children(&1, element_name_is("span")))
      |> Enum.to_list()

    assert result === [
             {"span", [],
              [
                "x",
                {"span", [], ["y"]}
              ]},
              {"span", [], ["y"]},
              {"span", [], ["y"]},
           ]
  end
end
