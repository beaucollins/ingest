defmodule DiscoveryTest do
  alias Ingest.Feed
  alias Ingest.Discovery

  use ExUnit.Case, async: true

  doctest Discovery

  test "finds redirect location" do
    assert Discovery.location([{"Location", "http://other"}]) == "http://other"
    assert Discovery.location([{"location", "http://other"}]) == "http://other"
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

    assert Discovery.find_feed_in_html(document) === [
             %Feed{url: "https://mock.host", title: "Feed Title"}
           ]
  end

  test "empty list of feeds when body is empty" do
    assert Discovery.find_feed_in_html("  ") === []
    assert Discovery.find_feed_in_html(nil) === []
  end

  test "fetch and parse" do
    assert Discovery.find_feed("http://test.blog") ===
             {:ok, "http://test.blog",
              [
                %Feed{host: "http://test.blog", title: "LOL", type: nil, url: "/some/where"}
              ]}

    assert Discovery.find_feeds(["http://gone.blog", "http://test.blog"]) === [
             {:error, "http://gone.blog", 404},
             {:ok, "http://test.blog",
              [%Feed{host: "http://test.blog", title: "LOL", type: nil, url: "/some/where"}]}
           ]
  end

  test "follows redirect" do
    assert Discovery.find_feed("http://redirect.blog") == {:error, "http://new.blog", 404}
  end
end
