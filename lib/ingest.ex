defmodule Ingest do
  @moduledoc """
  RSS Feed discovery

  Provides an HTTP API to search for RSS/alternate <link /> elements for given URL.
  """
  def fetch(url) do
    url
    |> Ingest.Client.get()
    |> case do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        case Ingest.Feed.parse(body) do
          {:ok, _} = ok ->
            ok

          {:error, _} ->
            {:error, "Could not fetch feed"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, headers: headers}}
      when status_code >= 300 and status_code < 400 ->
        case Ingest.Discovery.location(headers) do
          nil ->
            {:error, "Response #{status_code} with no redirect location"}

          location ->
            {:error, "Response #{status_code} redirect to #{location}"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Response #{status_code}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
