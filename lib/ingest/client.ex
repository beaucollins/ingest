defmodule Ingest.Client do
  @moduledoc """
  HTTP/S Client for fetching URLS
  """

  def get(%URI{} = url), do: get(URI.to_string(url))

  def get(url), do: HTTPoison.get(url, [], options())

  defp options do
    case Application.get_env(:ingest, :client)[:proxy] do
      nil -> []
      proxy -> [proxy: proxy]
    end
  end
end
