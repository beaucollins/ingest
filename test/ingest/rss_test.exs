defmodule Ingest.RSSTest do
  use ExUnit.Case
  alias Ingest.RSS
  alias Ingest.Source.Feed

  describe "Ingest.Source" do
    setup do
      %{
        feed: %RSS{
          url: "http://example.blig/feed.rss",
          title: "Awesome Feed"
        }
      }
    end

    test "url", %{feed: feed} do
      assert Feed.url(feed) === "http://example.blig/feed.rss"
    end

    test "title", %{feed: feed} do
      assert Feed.title(feed) === "Awesome Feed"
    end
  end
end
