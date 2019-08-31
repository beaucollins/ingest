defmodule Ingest.Service.Discover do
  require EEx
  use Plug.Builder
  alias Plug.Conn

  plug(Plug.Logger, log: :debug)

  plug(Plug.Parsers, parsers: [:urlencoded])
  plug(:dispatch)

  def dispatch(conn, _opts) do
    feed =
      Ingest.Discovery.find_feeds(
        case conn.params["url"] do
          urls when is_list(urls) -> urls
          single -> [single]
        end
      )

    case accepts(conn) do
      :html ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, template(feed))

      :json ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(Enum.map(feed, &Tuple.to_list/1)))
    end
  end

  EEx.function_from_file(:def, :template, "#{__DIR__}/views/discover.eex", [:feeds])

  defp accepts(conn, default_type \\ :html) do
    {_, accept} = List.keyfind(conn.req_headers, "accept", 0, {"accept", "text/html"})

    case Conn.Utils.media_type(accept) do
      {:ok, "text", "html", _} -> :html
      {:ok, "text", _, _} -> :plain
      {:ok, _, "json", _} -> :json
      _ -> default_type
    end
  end
end
