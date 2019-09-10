defmodule Ingest.Proxy do
  alias Plug.Conn
  use Plug.Builder

  plug(Plug.Logger, log: :debug)
  plug(:dispatch)

  def dispatch(conn = %Conn{method: "GET", host: host, request_path: path}, _opts) do
    conn
    |> send_html(content({host, path}))
  end

  defp send_html(conn, {status, content}) when is_integer(status) and is_binary(content) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, content)
  end

  defp send_html(conn, {status, headers, content}) do
    Enum.reduce(headers, conn, fn {key, value}, conn ->
      conn |> put_resp_header(key, value)
    end)
    |> put_resp_content_type("text/html")
    |> send_resp(status, content)
  end

  defp send_html(conn, content) do
    send_html(conn, {200, content})
  end

  defp content({"test.blog", _}) do
    """
    <html><head>
      <title>LOL</title>
      <link rel="alternate" href="/some/where" />
    </head></html>
    """
  end

  defp content({"awesome.blog", _}) do
    """
      <html>
        <title>So Awesome</title>
        <link rel="alternate" type="application/rss+xml" href="/feed.rss" />
        <link rel="alternate" type="application/rss+json" href="/feed.json" />
    """
  end

  defp content({"example.blog", "/"}) do
    """
    <html>
      <link title="" rel="alternate" href="/feed" />
      <link title="Example Title" rel="alternate" href="/feed" />
    """
  end

  defp content({"example.blog", "/feed"}) do
    File.read!("test/fixtures/example.blog-rss.xml")
  end

  defp content({"redirect.blog", _}) do
    {301, [{"location", "http://new.blog"}], "Redirect"}
  end

  defp content({"invalid.blog", _}) do
    "<invalid>"
  end

  defp content({"jsonfeed.blog", _}) do
    File.read!("test/fixtures/jsonfeed.blog-jsonfeed.json")
  end

  defp content(_) do
    {404, "<html><title>Not Found</title></html>"}
  end
end
