defmodule Ingest.Discovery do
  alias Ingest.Feed

  def find_feed(urls) when is_list(urls) do
    Enum.map(urls, fn url ->
      Task.async(fn ->
        find_feed(url)
      end)
    end)
    |> Enum.map(&Task.await/1)
    |> List.flatten
  end

  def find_feed(url) do
    IO.puts "Searching " <> url
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        IO.puts "Parsing response " <> url
        find_feed_in_html(body)

      {:ok, %HTTPoison.Response{status_code: code, headers: headers}}
      when code >= 300 and code <= 400 ->
        case location(headers) do
          nil -> {:error, "No location"}
          location -> find_feed(location)
        end
    end
  end

  def find_feed_in_html(body) do
    :mochiweb_html.parse(body)
    |> find_element(
      element_name_is("link")
      |> and_matches(attribute_is("rel", "alternate"))
      |> and_matches(contains_attribute("href"))
    )
    |> Enum.map(&node_as_feed/1)
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

  def node_as_feed(node) do
    %Feed{
      title: attribute(node, "title"),
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
end
