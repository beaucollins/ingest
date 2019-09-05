defmodule Ingest.Service do
  use Plug.Router
  require EEx

  plug(:match)
  plug(:dispatch)

  forward("/discover", to: Ingest.Service.Discover)
  forward("/info", to: Ingest.Service.FeedInfo)

  get("/", do: conn |> put_resp_content_type("text/html") |> send_resp(200, form()))

  match(_, do: conn |> send_resp(404, "not found"))

  EEx.function_from_file(:def, :form, "lib/ingest/service/views/form.eex")
end
