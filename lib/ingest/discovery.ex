defmodule Ingest.Discovery do
  @moduledoc """
  Given a URL or list of URLs, fetches the HTML and attempts to parse the
  alternate content types provided as RSS feeds.
  """
  import Traverse.Matcher
  alias Ingest.Feed
  alias Traverse.Document

  def find_feeds(urls) do
    Enum.map(urls, fn url ->
      Task.async(fn ->
        find_feed(url)
      end)
    end)
    |> Enum.map(&Task.await/1)
    |> List.flatten()
  end

  def find_feed(nil) do
    {:error, nil, :missing_url}
  end

  @doc """
  Fetches the URL and parses out potential RSS feeds.

      iex> Ingest.Discovery.find_feed("http://awesome.blog")
      { :ok, "http://awesome.blog", [
        %Feed{host: "http://awesome.blog", type: "application/rss+xml", title: "So Awesome", url: "/feed.rss"},
        %Feed{host: "http://awesome.blog", type: "application/rss+json", title: "So Awesome", url: "/feed.json"},
      ] }
  """
  def find_feed(url) when is_binary(url) do
    case Ingest.Client.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body, request_url: request_url}} ->
        {:ok, url, find_feed_in_html(body, request_url)}

      {:ok, %HTTPoison.Response{status_code: code, headers: headers}}
      when code >= 300 and code <= 400 ->
        case location(headers) do
          nil -> {:error, url, :redirect}
          location -> find_feed(location)
        end

      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, url, code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, url, reason}

      _ ->
        {:error, url, :unknown}
    end
  end

  def find_feed_in_html(document, document_url \\ "")

  def find_feed_in_html(nil, _url) do
    []
  end

  @doc """
  Parses the feed links from an HTML binary.

      iex> Ingest.Discovery.find_feed_in_html("<html><link rel=\\"alternate\\" title=\\"Feed\\" href=\\"lol\\"/></html>")
      [%Ingest.Feed{title: "Feed", type: nil, url: "lol"}]

      iex> Ingest.Discovery.find_feed_in_html("")
      []

  """
  def find_feed_in_html(body, url) when is_binary(body) do
    case String.trim(body) do
      "" ->
        []

      _ ->
        document = Traverse.parse(body)
        title = document_title(document)

        document
        |> Document.query_all(
          element_name_is("link")
          |> and_matches(attribute_is("rel", "alternate"))
          |> and_matches(contains_attribute("href"))
        )
        |> Enum.map(&node_as_feed(&1, title, url))
    end
  end

  def node_as_feed(node, title, url) do
    %Feed{
      host: url,
      title: Document.attribute(node, "title", title),
      url: Document.attribute(node, "href"),
      type: Document.attribute(node, "type")
    }
  end

  def location(headers) do
    header_value(
      headers,
      header_name_is("Location") |> or_header(header_name_is("location"))
    )
  end

  def header_value(headers, matcher) do
    Enum.find(headers, matcher)
    |> case do
      {_, value} -> value
      _ -> nil
    end
  end

  def header_name_is(name) do
    fn
      {header_name, _} when name == header_name -> true
      _ -> false
    end
  end

  def or_header(fn1, fn2) do
    fn value ->
      fn1.(value) == true || fn2.(value) == true
    end
  end

  @doc """
  Retrieve the DOM Document's title

      iex> Ingest.Discovery.document_title(Traverse.parse("<html><title>Page title</title><html>"))
      "Page title"
  """
  def document_title(fragment) do
    fragment
    |> Document.query(element_name_is("title"))
    |> Document.node_content()
  end
end
