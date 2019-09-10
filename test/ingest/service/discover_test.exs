defmodule Ingest.Service.DiscoverTest do
  use ExUnit.Case
  use Plug.Test

  alias Ingest.Service.Discover

  import Traverse.Matcher

  test "GET /" do
    conn = conn(:get, "/")
    conn = Discover.call(conn, [])

    assert conn.status == 200

    assert conn.resp_body |> Traverse.query(element_name_is("body")) |> Traverse.to_string() ==
             "<body><div><strong>Error</strong></div></body>"
  end
end
