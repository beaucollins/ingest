defmodule Simperium.Message.IndexRequest do
  @moduledoc """
  Request the Bucket index. A bucket's index is the list of keys and versions known
  by the bucket. Can optionally include each bucket object's data.

      iex> %Message.IndexRequest{
      ...>   include_data?: true,
      ...>   limit: 200,
      ...> }
      ...> |> encode()
      "i:1:::200"
  """
  defstruct [:include_data?, :offset, :mark, :limit]

  def next_page(command = %Simperium.Message.IndexPage{}, opts \\ []) do
    case command.mark do
      nil ->
        nil

      mark ->
        %__MODULE__{
          mark: mark,
          include_data?: Keyword.get(opts, :include_data?, true),
          limit: Keyword.get(opts, :limit, 100)
        }
    end
  end
end

defimpl Simperium.MessageEncoder, for: Simperium.Message.IndexRequest do
  def encode(%Simperium.Message.IndexRequest{
        include_data?: include_data?,
        limit: limit,
        mark: mark,
        offset: offset
      }) do
    "i:" <>
      ([
         if include_data? === true do
           1
         else
           nil
         end,
         mark,
         offset,
         limit
       ]
       |> Enum.join(":"))
  end
end
