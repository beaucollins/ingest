defmodule Ingest.Service.Nodes do
  use Plug.Router

  get "/" do
    case Jason.encode(%{remote: Node.list(), self: Node.self()}) do
      { :ok, content } ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, content)

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, ~s[{"error": "json"}])
    end
  end
end
