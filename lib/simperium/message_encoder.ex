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

defimpl Jason.Encoder, for: Simperium.Message.BucketInit do
  def encode(message, opts) do
    {_, map} =
      message
      |> Map.delete(:__struct__)
      |> Map.get_and_update(:cmd, fn
        nil -> :pop
        command -> {command, Simperium.MessageEncoder.encode(command)}
      end)

    Jason.Encode.map(map, opts)
  end
end
