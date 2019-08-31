defmodule Ingest.Service do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  forward("/discover", to: Ingest.Service.Discover)
  forward("/info", to: Ingest.Service.FeedInfo)

  get("/", do: conn |> send_resp(200, "welcome"))
end
