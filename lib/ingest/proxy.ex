defmodule Ingest.Proxy do
  alias Plug.Conn
  use Plug.Builder

  plug(Plug.Logger, log: :debug)
  plug(:dispatch)

  def dispatch(conn = %Conn{method: "GET", host: host}, _opts) do
    case host do
      "test.blog" ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, """
          <html><head>
            <title>LOL</title>
            <link rel="alternate" href="/some/where" />
          </head></html>
        """)

      "awesome.blog" ->
        conn
        |> send_resp(200, """
          <html>
            <title>So Awesome</title>
            <link rel="alternate" type="application/rss+xml" href="/feed.rss" />
            <link rel="alternate" type="application/rss+json" href="/feed.json" />
        """)

      _ ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(404, "<html><title>Not Found</title></html>")
    end
  end
end
