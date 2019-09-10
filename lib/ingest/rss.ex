defmodule Ingest.RSS do
  @enforce_keys [:url, :title]
  defstruct [:url, :title]
end

defimpl Ingest.Source.Feed, for: Ingest.RSS do
  def url(feed), do: feed.url

  def title(feed), do: feed.title
end
