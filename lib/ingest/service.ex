defmodule Ingest.Service do
  use Plug.Builder

  plug(Plug.Logger)

  plug(Plug.Static,
    from: :ingest,
    at: "/",
    only: ["style.css", "app.js", "app.html", "app.css"]
  )

  plug(Ingest.Service.App)
end
