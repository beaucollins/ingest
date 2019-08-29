defmodule Ingest.Service do
  use Plug.Builder
  alias Plug.Conn

  plug(Plug.Logger, log: :debug)

  plug(Plug.Parsers, parsers: [:urlencoded])
  plug(:wtf)

  def wtf(conn = %Conn{method: "POST"}, _opts) do
    feed = Ingest.Discovery.find_feed(conn.params["url"])

    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(feed))
  end
end
