defmodule Ingest.ClientTest do
  use ExUnit.Case

  test "get URL" do
    response =
      URI.parse("http://example.blog")
      |> Ingest.Client.get()

    case response do
      {:ok, response} ->
        assert response.status_code == 200
    end
  end
end
