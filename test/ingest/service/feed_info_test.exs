defmodule Ingest.Service.FeedInfoTest do
  use ExUnit.Case
  use Plug.Test

  import Ingest.HTMLHelpers
  import Traverse.Matcher
  import Requestor

  alias Ingest.Service.FeedInfo

  setup do
    %{opts: Ingest.Service.FeedInfo.init([])}
  end

  test_request FeedInfo,
               [],
               :get,
               "/" <> Ingest.Service.Discover.encode_uri("example.blog/feed") do
    assert conn.resp_body |> text(class_name_is("feed-title")) == "Very Legal & Very Cool"
  end

  test_request FeedInfo, [], :get, "/lol.blog" do
    assert conn.resp_body |> text(class_name_is("feed-meta")) === "Could not fetch feed\nlol.blog"
  end

  test_request FeedInfo, [], :get, "/redirect.blog" do
    assert conn.resp_body |> text(class_name_is("feed-meta")) ===
             "Could not fetch feed\nredirect.blog"

    assert conn.resp_body |> text(has_class_name("fetch-error")) ===
             "Reason:\nResponse 301 redirect to http://new.blog"
  end

  test_request FeedInfo, [], :get, "/invalid.blog" do
    assert conn.resp_body |> text(class_name_is("feed-meta")) ===
             "Could not parse feed: No valid parser for XML."

    assert conn.resp_body
           |> Traverse.parse()
           |> Traverse.query_all(element_name_is("pre"))
           |> Traverse.Document.node_content() ===
             "<invalid>"
  end

  test_request FeedInfo, [], :get, "/jsonfeed.blog" do
    assert conn.resp_body |> text(class_name_is("feed-title")) === "JSONFeed Blog"
  end
end
