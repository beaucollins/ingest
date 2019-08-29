defmodule Ingest.Feed do
  @derive {Jason.Encoder, only: [:host, :title, :url, :type]}
  defstruct host: "", type: "application/rss+xml", title: "", url: ""

  def fetch(feed = %__MODULE__{}) do
    IO.puts("Fetch feed " <> feed.url)

    case HTTPoison.get(feed.url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, code}
    end
  end
end
