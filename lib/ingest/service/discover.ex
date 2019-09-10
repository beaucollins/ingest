defmodule Ingest.Service.Discover do
  require EEx
  use Plug.Builder
  use Ingest.Web.Views

  plug(Plug.Parsers, parsers: [:urlencoded])
  plug(:dispatch)

  def dispatch(conn, _opts) do
    feeds =
      Ingest.Discovery.find_feeds(
        case conn.params["url"] do
          urls when is_list(urls) -> urls
          single -> [single]
        end
      )

    render(conn, "discover.html", %{feeds: feeds})
  end

  def encode_uri(%URI{} = uri) do
    uri
    |> URI.to_string()
    |> encode_uri
  end

  def encode_uri(uri) when is_binary(uri) do
    URI.encode(uri, &URI.char_unreserved?/1)
  end

end
