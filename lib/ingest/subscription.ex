defmodule Ingest.Subscription do
  @enforce_keys [:feed_url, :subscriber]
  defstruct [:subscriber, :feed_url]

  @doc """
  Build a subscription for a Feed for a given subscriber.

      iex> %Ingest.Feed{url: "http://example.blog/feed"}
      ...> |> Ingest.Subscription.subscribe("user@host")
      %Ingest.Subscription{feed_url: "http://example.blog/feed", subscriber: "user@host"}
  """
  def subscribe(feed = %Ingest.Feed{}, subscriber) do
    %Ingest.Subscription{feed_url: feed.url, subscriber: subscriber}
  end
end
