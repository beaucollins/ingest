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
