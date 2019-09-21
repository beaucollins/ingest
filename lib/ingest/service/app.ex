defmodule Ingest.Service.App do
  use Plug.Router
  use Ingest.Web.Views

  plug(:match)
  plug(:dispatch)

  forward("/discover", to: Ingest.Service.Discover)
  forward("/info", to: Ingest.Service.FeedInfo)
  forward("/nodes", to: Ingest.Service.Nodes)

  get("/", do: conn |> render("form.html", %{url: url_param(conn)}))

  match(_, do: conn |> render(404, "404.html"))

  defp url_param(%Plug.Conn{} = conn) do
    conn
    |> fetch_query_params
    |> Map.get(:params)
    |> url_param
  end

  defp url_param(%{} = params), do: Map.get(params, "url") |> url_param

  defp url_param("") do
    url_param(nil)
  end

  defp url_param(param) when is_binary(param) do
    param
  end

  defp url_param(_param) do
    "https://beau.collins.pub"
  end
end
