defmodule Ingest.Discovery do
  alias Ingest.Feed

  def find_feed(urls) when is_list(urls) do
    Enum.map(urls, fn url ->
      Task.async(fn ->
        find_feed(url)
      end)
    end)
    |> Enum.map(&Task.await/1)
    |> List.flatten()
  end

  def find_feed(nil) do
    []
  end

  @doc """
  Fetches the URL and parses out potential RSS feeds.

    iex> Ingest.Discovery.find_feed("http://awesome.blog")
    [
      %Feed{host: "http://awesome.blog", type: "application/rss+json", title: "So Awesome", url: "/feed.json"},
      %Feed{host: "http://awesome.blog", type: "application/rss+xml", title: "So Awesome", url: "/feed.rss"}
    ]
  """
  def find_feed(url) when is_binary(url) do
    IO.puts("Searching " <> url)

    case Ingest.Client.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body, request_url: request_url}} ->
        IO.puts("Parsing response " <> request_url)
        find_feed_in_html(body, request_url)

      {:ok, %HTTPoison.Response{status_code: code, headers: headers}}
      when code >= 300 and code <= 400 ->
        case location(headers) do
          nil -> {:error, "No location"}
          location -> find_feed(location)
        end
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
        document = :mochiweb_html.parse(body)
        title = document_title(document)

        document
        |> find_element(
          element_name_is("link")
          |> and_matches(attribute_is("rel", "alternate"))
          |> and_matches(contains_attribute("href"))
        )
        |> Enum.map(&node_as_feed(&1, title, url))
    end
  end

  def find_element(node, matcher, acc \\ [])

  def find_element(fragment, matcher, acc) when is_list(fragment) do
    Enum.reduce(fragment, acc, fn
      node = {_element, _attributes, children}, matches ->
        find_element(
          children,
          matcher,
          if matcher.(node) do
            [node | matches]
          else
            matches
          end
        )

      _, matches ->
        matches
    end)
  end

  def find_element(node = {_element, _attributes, _children}, matcher, acc) do
    find_element([node], matcher, acc)
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

  def element_name_is(name) do
    fn
      {element, _attributes, _children} when element == name ->
        true

      _ ->
        false
    end
  end

  def and_matches(fn1, fn2) do
    fn value -> fn1.(value) && fn2.(value) end
  end

  def attribute_is(attributeName, attributeValue) do
    fn
      {_, atts, _} ->
        Enum.find(atts, fn
          {name, value} when attributeName == name and attributeValue == value -> true
          _ -> false
        end)
    end
  end

  def node_as_feed(node, title, url) do
    %Feed{
      host: url,
      title: attribute(node, "title", title),
      url: attribute(node, "href"),
      type: attribute(node, "type")
    }
  end

  def attribute({_type, attributes, _children}, name, defaultTo \\ nil) do
    Enum.find(attributes, fn
      {key, _} when key == name -> true
      _ -> false
    end)
    |> case do
      {_, value} -> value
      _ -> defaultTo
    end
  end

  def contains_attribute(attributeName) do
    fn
      {_, [], _children} ->
        false

      {_, attributes, _children} when is_list(attributes) ->
        Enum.find(attributes, fn
          {name, _value} when name == attributeName ->
            true

          _ ->
            false
        end)

      _ ->
        false
    end
  end

  @doc """
    iex> Ingest.Discovery.document_title(:mochiweb_html.parse("<html><title>Page title</title><html>"))
    "Page title"
  """
  def document_title(fragment, defaultTo \\ "") do
    fragment
    |> find_element(element_name_is("title"))
    |> node_content(defaultTo)
    |> case do
      [] -> defaultTo
      [head | _rest] -> head
    end
  end

  def node_content(fragment, defaultTo \\ "")

  def node_content(fragment, defaultTo) when is_list(fragment) do
    Enum.map(fragment, &node_content(&1, defaultTo))
  end

  def node_content({_type, _attributes, children}, defaultTo) do
    case children do
      [] -> defaultTo
      _ -> Enum.reduce(children, &(&1 <> "\n" <> &2))
    end
  end
end
