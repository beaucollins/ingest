defmodule Ingest.Service.Nodes do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    %{
      remote: Node.list(),
      self: Node.self()
    }
    |> Jason.encode()
    |> case do
      {:ok, content} ->
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
