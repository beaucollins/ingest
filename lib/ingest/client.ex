defmodule Ingest.Client do
  @moduledoc """
  HTTP/S Client for fetching URLS
  """

  def get(url) do
    HTTPoison.get(url, [], options())
  end

  defp options do
    case Application.get_env(:ingest, :client)[:proxy] do
      nil -> []
      proxy -> [proxy: proxy]
    end
  end
end
