defmodule Ingest.Service.NodesTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import Requestor
  alias Ingest.Service.Nodes

  test_request(Nodes, [], :get, "/")
end
