defmodule Ingest.ServiceTest do
  use ExUnit.Case
  use Plug.Test
  import Requestor

  test_request(Ingest.Service, [], :get, "/")
  test_request(Ingest.Service, [], :get, "/info/example.blog%2Afeed")

  test_request(Ingest.Service, [], :get, "/style.css") do
    assert conn.state == :file
    assert conn.status == 200
    assert File.read!("priv/static/style.css") == conn.resp_body
  end

  test_request Ingest.Service, [], :get, "/not-found" do
    assert conn.status == 404
  end
end
