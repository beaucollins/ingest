defmodule Ingest.Service.DiscoverTest do
  use ExUnit.Case, async: true
  use Plug.Test
  require Requestor
  alias Ingest.Service.Discover

  import Traverse.Matcher

  test "GET /" do
    conn = conn(:get, "/")
    conn = Discover.call(conn, [])

    assert conn.status == 200

    assert conn.resp_body
           |> Traverse.query_all(has_class_name("site-feeds"))
           |> Traverse.to_string() ==
             ~s[<section class="site-feeds"><div><strong>Error</strong></div></section>]
  end

  test "GET with url" do
    conn = conn(:get, "?url=awesome.blog")
    conn = Discover.call(conn, [])

    assert conn.status == 200

    refute "<span class=\"feed-title\" />" ==
             conn.resp_body
             |> Traverse.query(has_class_name("feed-title"))
             |> Traverse.to_string()
  end

  test "GET with multiple urls" do
    conn = conn(:get, "?url[]=awesome.blog&url[]=example.blog")
    conn = Discover.call(conn, [])

    assert conn.status == 200

    titles =
      conn.resp_body
      |> Traverse.query_all(has_class_name("feed-title"))
      |> Enum.map(&Traverse.to_string/1)

    assert titles == [
             "<span class=\"feed-title\">So Awesome</span>",
             "<span class=\"feed-title\">So Awesome</span>",
             "<span class=\"feed-title\"><em>Untitled</em></span>",
             "<span class=\"feed-title\">Example Title</span>"
           ]
  end
end
