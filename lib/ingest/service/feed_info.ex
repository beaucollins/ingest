defmodule Ingest.Service.FeedInfo do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/:url" do
    url
    |> URI.decode()
    |> Ingest.Client.get()
    |> case do
      {:ok, %HTTPoison.Response{body: body}} ->
        try do
          body
          |> Ingest.Feed.parse()
          |> case do
            %{} = feed ->
              conn
              |> put_resp_content_type("text/html")
              |> send_resp(200, """
              <table>
                <tbody>
                  <tr><th scope="row">URL</th><td>#{feed_link(feed)}</td></tr>
                  <tr><th scope="row">Title</th><td>#{feed_title(feed)}</td></tr>
                  <tr><th scope="row">Description</th><td>#{feed_description(feed)}</td></tr>
                </tbody>
              </table>
              #{entry_list(feed)}
              """)
          end
        rescue
          e in RuntimeError ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(200, """
            Could not parse feed: #{Exception.message(e)}
            ---
            #{body}
            """)
        end

      {:error, reason} ->
        conn |> send_resp(200, "Failed to fetch #{inspect(url)} becase #{reason}")
    end
  end

  match _ do
    conn |> send_resp(404, "Not found")
  end

  defp feed_title(%{} = feed), do: Map.get(feed, "title", Map.get(feed, :title))

  defp feed_title(_feed) do
    "<em>Untitled</em>"
  end

  defp feed_url(%{} = feed), do: Map.get(feed, "url", Map.get(feed, :url))

  defp feed_url(_feed), do: nil

  defp feed_link(feed, link_text \\ &feed_url/1) do
    case feed_url(feed) do
      url when is_binary(url) ->
        "<a href=#{url}>#{link_text.(feed)}</a>"

      _ ->
        "<em>No link</em>"
    end
  end

  defp feed_description(%{description: description}) do
    description
  end

  defp feed_description(_description) do
    "<em>No description</em>"
  end

  defp entry_list(%{entries: entries = []}) when is_list(entries) do
    ~s(<p>No entries</p>)
  end

  defp entry_list(%{entries: entries}) when is_list(entries) do
    """
    <ul>
      #{entries |> Enum.map(&entry_item/1) |> Enum.join("\n")}
    </ul>
    """
  end

  defp entry_list(%{} = feed) do
    entry_list(%{entries: Map.get(feed, "items")})
  end

  defp entry_list(_feed) do
    "<em>No entries found</em>"
  end

  defp entry_item(item) do
    case item do
      %{} = item ->
        """
        <li>
          <a href="#{entry_item_url(item)}">
            #{entry_item_title(item)}
          </a>
          <p>#{entry_item_published_date(item)}</p>
          #{entry_summary(item)}
          <p><small>#{Map.keys(item) |> Enum.join(", ")}</small></p>
        </li>
        """
    end
  end

  defp entry_summary(item) do
    case item do
      %{summary: summary} ->
        "<p>#{summary}</p>"

      _ ->
        ""
    end
  end

  defp entry_item_url(%{url: url}) do
    url
  end

  defp entry_item_url(%{} = item) do
    Map.get(item, "url")
  end

  defp entry_item_title(%{title: title}) when is_binary(title) do
    title
  end

  defp entry_item_title(_item) do
    "<em>Untitled</em>"
  end

  defp entry_item_published_date(%{published: published}) do
    published
  end

  defp entry_item_published_date(_item) do
    "<em>Unknown publish date</em>"
  end
end
