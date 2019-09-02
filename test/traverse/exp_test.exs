defmodule Traverse.ExpTest do
  use ExUnit.Case

  import Traverse.Matcher

  test "descendants" do
    # Trying to come up with the equivalent of
    # document.querySelector("div .thing")
    #
    # So fist do a query all on "div" and then a query all on ".thing"
    document =
      Traverse.parse("""
        <html>
        <body>
          <div></div>
          <div><span id="correct" class="thing"></div>
          <div><span id="incorrect"></div>
          <span id="incorrect" class="thing">
        </body>
      """)

    assert document
           |> stream(element_name_is("div"))
           |> Stream.map(&stream(&1, "class" |> attribute_is("thing")))
           |> Stream.concat()
           |> Enum.to_list() ===
             [{"span", [{"id", "correct"}, {"class", "thing"}], []}]
  end
end
