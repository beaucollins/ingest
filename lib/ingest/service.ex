defmodule Ingest.Service do
  use Plug.Builder
  alias Plug.Conn

  plug(Plug.Logger, log: :debug)

  plug(Plug.Parsers, parsers: [:urlencoded])
  plug(:dispatch)

  def dispatch(conn = %Conn{method: "POST"}, _opts) do
    feed =
      Ingest.Discovery.find_feeds(
        case conn.params["url"] do
          urls when is_list(urls) -> urls
          single -> [single]
        end
      )

    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(Enum.map(feed, &Tuple.to_list/1)))
  end
end
