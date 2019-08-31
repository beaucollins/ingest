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
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "Got body \n\n---\n\n#{body}")

      {:error, reason} ->
        conn |> send_resp(200, "Failed to fetch #{inspect(url)} becase #{reason}")
    end
  end

  match _ do
    conn |> send_resp(404, "Not found")
  end
end
