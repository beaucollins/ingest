defmodule Ingest.Service.FeedInfoTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Traverse.Matcher
  import Requestor

  alias Ingest.Service.FeedInfo

  setup do
    %{opts: Ingest.Service.FeedInfo.init([])}
  end

  defp text(body_data, query) do
    body_data |> Traverse.query(query) |> Traverse.Document.node_content()
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
             "Could not fetch feed\ninvalid.blog"

    # assert conn.resp_body
    #        |> text(element_name_is("pre")) ===
    #          "<invalid>"
  end

  test_request FeedInfo, [], :get, "/jsonfeed.blog" do
    assert conn.resp_body |> text(class_name_is("feed-title")) === "JSONFeed Blog"
  end
end
