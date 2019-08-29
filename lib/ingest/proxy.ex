defmodule Ingest.Proxy do
  alias Plug.Conn
  use Plug.Builder

  plug(Plug.Logger, log: :debug)
  plug(:dispatch)

  def dispatch(conn = %Conn{method: "GET", host: host}, _opts) do
    conn
    |> send_html(
      case host do
        "test.blog" ->
          """
            <html><head>
              <title>LOL</title>
              <link rel="alternate" href="/some/where" />
            </head></html>
          """

        "awesome.blog" ->
          """
            <html>
              <title>So Awesome</title>
              <link rel="alternate" type="application/rss+xml" href="/feed.rss" />
              <link rel="alternate" type="application/rss+json" href="/feed.json" />
          """

        _ ->
          {404, "<html><title>Not Found</title></html>"}
      end
    )
  end

  defp send_html(conn, {status, content}) when is_integer(status) and is_binary(content) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, content)
  end

  defp send_html(conn, content) do
    send_html(conn, {200, content})
  end
end
