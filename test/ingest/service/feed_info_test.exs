defmodule Ingest.Service.FeedInfoTest do
  use ExUnit.Case
  use Plug.Test

  import Ingest.HTMLHelpers
  import Traverse.Matcher

  setup do
    %{opts: Ingest.Service.FeedInfo.init([])}
  end

  test "GET feed", %{opts: opts} do
    conn = conn(:get, "/" <> Ingest.Service.Discover.encode_uri("example.blog"))
    conn = Ingest.Service.FeedInfo.call(conn, opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> text(class_name_is("feed-title")) == "Very Legal & Very Cool"
  end

  test "GET missing feed", %{opts: opts} do
    conn = conn(:get, "/lol.blog")
    conn = Ingest.Service.FeedInfo.call(conn, opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body |> text(class_name_is("feed-meta")) === "Could not fetch feed\nlol.blog"
  end

  test "GET redirected feed", %{opts: opts} do
    conn = conn(:get, "/redirect.blog")
    conn = Ingest.Service.FeedInfo.call(conn, opts)

    assert conn.state == :sent
    assert conn.status == 200

    assert conn.resp_body |> text(class_name_is("feed-meta")) ===
             "Could not fetch feed\nredirect.blog"

    assert conn.resp_body |> text(has_class_name("fetch-error")) ===
             "Reason:\nResponse 301 redirect to http://new.blog"
  end

  test "GET invalid feed", %{opts: opts} do
    conn = conn(:get, "/invalid.blog")
    conn = Ingest.Service.FeedInfo.call(conn, opts)

    assert conn.state == :sent
    assert conn.status == 200

    assert conn.resp_body |> text(class_name_is("feed-meta")) ===
             "Could not parse feed: No valid parser for XML."

    assert conn.resp_body
           |> Traverse.parse()
           |> query_all(element_name_is("pre"))
           |> Traverse.Document.node_content() ===
             "<invalid>"
  end
end
