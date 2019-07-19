defmodule IngestTest do
  use ExUnit.Case
  doctest Ingest

  test "finds redirect location" do
    assert Ingest.location([{"Location", "http://other"}]) == "http://other"
    assert Ingest.location([{"location", "http://other"}]) == "http://other"
  end

  test "finds feed url in document" do
    document = "<html>
        <head lang=\"en\">
          <link rel=\"alternate\" type=\"application/rss+xml\" href=\"https://mock.host\" title=\"Feed Title\">
          <link rel=\"alternate\" type=\"application/rss+xml\" title=\"Feed Title\">
          <link rel=\"stylesheet\" type=\"text/css\" href=\"https://mock.host\" title=\"Feed Title\">
        </head>
        <body><p>Hi</p></body>
      </html>"

    assert Ingest.find_feed_in_html(document) === [
             %Feed{url: "https://mock.host", title: "Feed Title"}
           ]
  end

  test "finds by attribute" do
    document = "<body><a class=\"\" href=\"hello\" /><a href=\"other\" /></body>"

    found =
      Ingest.find_element(:mochiweb_html.parse(document), Ingest.contains_attribute("class"))

    assert found === [{"a", [{"class", ""}, {"href", "hello"}], []}]
  end

  test "combines matchers" do
    document =
      "<body><a class=\"\" href=\"hello\" /><a href=\"other\" /></body>" |> :mochiweb_html.parse()

    found =
      document
      |> Ingest.find_element(
        Ingest.contains_attribute("class")
        |> Ingest.and_matches(Ingest.element_name_is("a"))
      )

    assert found === [{"a", [{"class", ""}, {"href", "hello"}], []}]
  end
end
