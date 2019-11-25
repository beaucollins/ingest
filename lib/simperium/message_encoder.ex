defprotocol Simperium.MessageEncoder do
  @moduledoc """
  Implementing this protocol allows the `Simperium.Connection` to
  send the message to the Simperium service.
  """
  @doc """
  Encodes the message to be sent to the Simperium syncing service.
  """
  @spec encode(any) :: iodata
  def encode(message)
end

defimpl Simperium.MessageEncoder, for: Simperium.Message.BucketInit do
  def encode(bucket_init) do
    "init:" <> Jason.encode!(bucket_init)
  end
end

defimpl Simperium.MessageEncoder, for: Simperium.Message.Heartbeat do
  def encode(%Simperium.Message.Heartbeat{count: count}) do
    "h:" <> to_string(count)
  end
end

defimpl Simperium.MessageEncoder, for: Simperium.Message.ChangeVersion do
  def encode(%Simperium.Message.ChangeVersion{cv: cv}) do
    "cv:" <> cv
  end
end

defimpl Simperium.MessageEncoder, for: Simperium.Message.ObjectVersion do
  def encode(%Simperium.Message.ObjectVersion{key: key, version: version}) do
    "e:" <> key <> "." <> to_string(version)
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

defimpl Simperium.MessageEncoder, for: Simperium.Message.ChangeRequest do
  def encode(change = %Simperium.Message.ChangeRequest{}) do
    keys = [:clientid, :cv, :ev, :id, :o, :ccid]

    "c:" <> Jason.encode!(Map.take(change, keys))
  end
end

defimpl Jason.Encoder, for: Simperium.Message.BucketInit do
  def encode(message, opts) do
    keys =
      Map.keys(message) --
        case message.cmd do
          nil -> [:__struct__, :cmd]
          _ -> [:__struct__]
        end

    Map.take(message, keys) |> Jason.Encode.map(opts)
  end
end
