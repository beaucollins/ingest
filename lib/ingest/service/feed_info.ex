defmodule Ingest.Service.FeedInfo do
  use Plug.Router
  use Ingest.Web.Views

  plug(:match)
  plug(:dispatch)

  get "/:url" do
    url
    |> URI.decode()
    |> Ingest.Client.get()
    |> case do
      {:ok, %HTTPoison.Response{body: body}} ->
        try do
          case Ingest.Feed.parse(body) do
            %{} = feed ->
              render(conn, "feed.html", %{feed: feed})
          end
        rescue
          e in RuntimeError ->
            render(conn, "parse_error.html", %{exception: e, body: body})
        end

      {:error, reason} ->
        render(conn, "fetch_error.html", %{error: reason, url: url})
    end
  end

  match _ do
    conn |> send_resp(404, "Not found")
  end
end

defmodule Ingest.View.DateTime do
  def display(<<_::utf8, _::binary>> = date) do
    case Ingest.DateTime.parse(date) do
      {:ok, parsed} ->
        display(parsed)

      {:error, _} ->
        {:error, date}
    end
  end

  def display(%DateTime{} = date) do
    {:ok, DateTime.to_iso8601(date)}
  end
end

defmodule Ingest.DateTime do
  @formats [
    {17, "{YYYY}-{0M}-{0D} {h24}:{0m}Z"},
    {20, "{YYYY}-{0M}-{0D} {h24}:{0m}{0s}Z"},
    {25, "{YYYY}-{0M}-{0D} {h24}:{0m}:{0s}{Z:}"},
    {23, "{YYYY}-{0M}-{0D} {h24}:{0m}:{0s} {Zabbr}"}
  ]

  def parse!(date) do
    case parse(date) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise reason
    end
  end

  def parse(date) do
    @formats
    |> Enum.reduce(nil, fn
      _, {:ok, _} = result ->
        result

      {len, format}, _ ->
        String.slice(date, 0, len)
        |> Timex.parse(format)
        |> case do
          {:ok, d = %NaiveDateTime{}} = result ->
            case DateTime.from_naive(d, "Etc/UTC") do
              {:ok, _} = success ->
                success

              _ ->
                result
            end

          result ->
            result
        end
    end)
  end
end
