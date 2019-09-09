defmodule Ingest.Web.Views do
  use Phoenix.View,
    root: "lib/ingest/templates",
    namespace: Ingest

  use Phoenix.HTML

  defmacro __using__(_opts) do
    quote do
      def render(conn, status \\ 200, template, assigns \\ %{})

      def render(conn, status, template, assigns)
          when is_integer(status) and is_binary(template) do
        body = Ingest.Web.Views.render(template, assigns)

        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_resp(
          status,
          case Ingest.Web.Layout.render("layout.html", body: body) do
            {:safe, content} -> content
          end
        )
      end

      def render(conn, template, assigns, _unused) when is_binary(template) do
        render(conn, 200, template, assigns)
      end
    end
  end

  defp feed_title(%{} = feed), do: Map.get(feed, "title", Map.get(feed, :title))

  defp feed_title(_feed) do
    content_tag(:em, "Untitled")
  end

  defp feed_url(%{} = feed), do: Map.get(feed, "url", Map.get(feed, :url))

  defp feed_url(_feed), do: nil

  defp feed_link(feed, link_text \\ &feed_url/1) do
    case feed_url(feed) do
      url when is_binary(url) ->
        content_tag :a, href: url do
          link_text.(feed)
        end

      _ ->
        content_tag(:em, "No link")
    end
  end

  defp feed_description(%{description: description}) do
    description
  end

  defp feed_description(_description) do
    content_tag(:em, "No description")
  end

  defp entry_list(%{entries: entries = []}) when is_list(entries) do
    content_tag(:em, "No entries")
  end

  defp entry_list(%{entries: entries}) when is_list(entries) do
    content_tag(:ol, for(entry <- entries, do: entry_item(entry)))
  end

  defp entry_list(%{} = feed) when is_map(feed) do
    entry_list(%{entries: Map.get(feed, "items")})
  end

  defp entry_list(_feed) do
    content_tag(:em, "No entries found")
  end

  defp entry_item(item) do
    case item do
      %{} = item ->
        content_tag(:li) do
          [
            content_tag(:a, href: entry_item_url(item)) do
              entry_item_title(item)
            end,
            content_tag(:p, entry_item_published_date(item)),
            entry_summary(item),
            content_tag(:p) do
              content_tag(:small) do
                Map.keys(item) |> Enum.join(", ")
              end
            end,
            entry_content(item)
          ]
        end
    end
  end

  defp entry_content(item) do
    case item do
      %{content: content} ->
        content_tag(:div) do
          content
          |> Ingest.Sanitize.sanitize_html()
          |> raw
        end

      _ ->
        ""
    end
  end

  defp entry_summary(item) do
    case item do
      %{summary: summary} ->
        content_tag(:div) do
          summary
          |> Ingest.Sanitize.sanitize_html()
          |> raw
        end

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
    content_tag(:em, "Untitled")
  end

  defp entry_item_published_date(%{published: published}) do
    published |> Ingest.View.DateTime.display() |> entry_item_published_date
  end

  defp entry_item_published_date({:ok, formatted}) do
    content_tag(:small, formatted)
  end

  defp entry_item_published_date({:error, original}) do
    content_tag(:em, original)
  end

  defp entry_item_published_date(_item), do: content_tag(:em, "Unknown publish date")

  defp error_reason(error) do
    case error do
      message when is_binary(message) -> message
      exception -> Exception.message(exception)
    end
  end
end
