defmodule Ingest.ServiceTest do
  use ExUnit.Case
  use Plug.Test

  test "get home page" do
    conn = conn(:get, "/")
    conn = Ingest.Service.call(conn, Ingest.Service.init([]))

    assert conn.state == :sent
    assert conn.status == 200
  end

  test "get css" do
    conn = conn(:get, "/style.css")
    conn = Ingest.Service.call(conn, Ingest.Service.init([]))

    assert conn.state == :file
    assert conn.status == 200

    assert File.read!("priv/static/style.css") == conn.resp_body
  end
end
