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
