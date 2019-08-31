defmodule Ingest.Feed do
  @derive {Jason.Encoder, only: [:host, :title, :url, :type]}
  defstruct host: "", type: "application/rss+xml", title: "", url: ""

  def fetch(feed = %__MODULE__{}) do
    case Ingest.Client.get(url(feed)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, code}
    end
  end

  @doc """
  Computes the absolute URL for requesting the feed content

      iex> Ingest.Feed.url(%Ingest.Feed{url: "https://example.blog/some/feed"})
      ...> |> URI.to_string
      "https://example.blog/some/feed"

  When a feed's url is relative it uses the feed's host page to determine the
  full url.

      iex> alias Ingest.Feed
      iex> Feed.url(%Feed{url: "/some/resource", host: "http://example.blog/some-page"})
      ...> |> URI.to_string
      "http://example.blog/some/resource"
  """
  def url(feed = %__MODULE__{}) do
    URI.parse(feed.url)
    |> case do
      %URI{authority: nil} = uri ->
        URI.merge(
          URI.parse(feed.host),
          uri
        )

      uri ->
        uri
    end
  end
end
