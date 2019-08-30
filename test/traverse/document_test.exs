defmodule Traverse.DocumentTest do
  alias Traverse.Document
  alias Traverse.Matcher

  use ExUnit.Case

  doctest Traverse.Document

  test "combines matchers" do
    document = """
      <body>
        <a class="" href="hello" /><a href="other" />
      </body>
    """
    |> :mochiweb_html.parse()

    found =
      document
      |> Document.find_element(
        Matcher.contains_attribute("class")
        |> Matcher.and_matches(Matcher.element_name_is("a"))
      )

    assert found === [{"a", [{"class", ""}, {"href", "hello"}], []}]
  end

  test "finds by attribute" do
    document = """
      <body>
        <a class="" href="hello" /><a href="other" />
      </body>
    """

    found =
      Document.find_element(
        :mochiweb_html.parse(document),
        Matcher.contains_attribute("class")
      )

    assert found === [{"a", [{"class", ""}, {"href", "hello"}], []}]
  end

end
