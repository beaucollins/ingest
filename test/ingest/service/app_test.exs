defmodule Ingest.Service.AppTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import Requestor
  alias Ingest.Service.App

  test_request App, [], :get, "/discover" do
    assert conn.state == :sent
  end
end
