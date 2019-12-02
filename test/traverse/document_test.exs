defmodule Traverse.DocumentTest do
  alias Traverse.Document
  alias Traverse.Matcher

  use ExUnit.Case, async: true

  doctest Traverse.Document

  test "combines matchers" do
    document =
      Traverse.parse("""
        <body>
          <a class="" href="hello" /><a href="other" />
        </body>
      """)

    found =
      document
      |> Document.query_all(
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
      Document.query_all(
        Traverse.parse(document),
        Matcher.contains_attribute("class")
      )

    assert found === [{"a", [{"class", ""}, {"href", "hello"}], []}]
  end

  describe "to_string" do
    test "comment fragment" do
      assert Document.to_string({:comment, "Not content"}) === "<!--Not content-->"
    end

    test "attributes escaped" do
      assert Document.to_string({"div", [{"data-thing", "{\"json\": \"value\"}"}], ["hello"]})
             |> Document.to_string() ===
               ~s[<div data-thing="{\"json\": \"value\"}">hello</div>]
    end
  end

  test "node_content" do
    content =
      """
      <div><strong>Hello</strong> World</div>
      """
      |> Traverse.parse()
      |> Traverse.Document.node_content()

    assert content === "Hello\nWorld"
  end

  test "iframe always has closing tag" do
    html =
      {"iframe", [], []}
      |> Traverse.Document.to_string()

    assert html == "<iframe></iframe>"
  end
end
