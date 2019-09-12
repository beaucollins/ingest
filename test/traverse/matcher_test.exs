defmodule Traverse.MatcherTest do
  use ExUnit.Case
  alias Traverse.Matcher
  doctest Matcher

  setup do
    [
      graph: :mochiweb_html.parse(~s(
        <html>
          <head></head>
          <body>
            <div>Hello <span>there</span>.</div>
            <div>:\)</div>
            <!-- ignored -->
          </body>
      ))
    ]
  end

  test "graph stream", context do
    stream = Traverse.Document.stream(context[:graph])

    identifier = fn
      text when is_binary(text) -> {:text, text}
      {:comment, comment} -> {:comment, comment}
      {element, _, _} -> {:element, element}
    end

    assert Enum.map(stream, identifier) === [
             element: "html",
             element: "head",
             element: "body",
             element: "div",
             element: "div",
             comment: " ignored ",
             text: "Hello ",
             element: "span",
             text: ".",
             text: ":)",
             text: "there"
           ]
  end

  test "filter stream", context do
    matches =
      Traverse.Document.stream(context[:graph], Matcher.element_name_is("div"))
      |> Enum.to_list()

    assert [
             {"div", [], ["Hello ", {"span", [], ["there"]}, "."]},
             {"div", [], [":)"]}
           ] === matches
  end

  test "query for the first match", context do
    assert {"div", [], ["Hello ", {"span", [], ["there"]}, "."]} ===
             Traverse.query(
               context[:graph],
               Matcher.element_name_is("div")
               |> Matcher.or_matches(Matcher.element_name_is("span"))
             )
  end
end
