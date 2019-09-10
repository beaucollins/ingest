defmodule Ingest.Service.FeedInfo do
  use Plug.Router
  use Ingest.Web.Views

  plug(:match)
  plug(:dispatch)

  get "/:url" do
    url
    |> URI.decode()
    |> Ingest.Client.get()
    |> case do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        try do
          case Ingest.Feed.parse(body) do
            %{} = feed ->
              render(conn, "feed.html", %{feed: feed})
          end
        rescue
          e in RuntimeError ->
            render(conn, "parse_error.html", %{exception: e, body: body})
        end

      {:ok, %HTTPoison.Response{status_code: status_code, headers: headers}}
      when status_code >= 300 and status_code < 400 ->
        case Ingest.Discovery.location(headers) do
          nil ->
            render(conn, "fetch_error.html", %{error: "Response #{status_code}", url: url})

          location ->
            render(conn, "fetch_error.html", %{
              error: "Response #{status_code} redirect to #{location}",
              url: url
            })
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        render(conn, "fetch_error.html", %{error: "Response #{status_code}", url: url})

      {:error, reason} ->
        render(conn, "fetch_error.html", %{error: reason, url: url})
    end
  end
end
