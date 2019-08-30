defmodule Ingest.TraverseTest do
  alias Ingest.Traverse
  use ExUnit.Case

  doctest Ingest.Traverse

  test "combines matchers" do
    document = """
      <body>
        <a class="" href="hello" /><a href="other" />
      </body>
    """
    |> :mochiweb_html.parse()

    found =
      document
      |> Traverse.find_element(
        Traverse.contains_attribute("class")
        |> Traverse.and_matches(Traverse.element_name_is("a"))
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
      Traverse.find_element(
        :mochiweb_html.parse(document),
        Traverse.contains_attribute("class")
      )

    assert found === [{"a", [{"class", ""}, {"href", "hello"}], []}]
  end

end
