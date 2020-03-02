defmodule Ingest.Service.FeedInfo do
  use Plug.Router
  use Ingest.Web.Views

  plug(:match)
  plug(:dispatch)

  get "/:url" do
    url
    |> URI.decode()
    |> Ingest.fetch()
    |> case do
      {:ok, feed} when is_map(feed) ->
        render(conn, "feed.html", %{feed: feed})

      {:error, reason} ->
        render(conn, "fetch_error.html", %{error: reason, url: url})

    end
  end
end
