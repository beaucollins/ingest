defprotocol Simperium.MessageDebug do
  @fallback_to_any true
  def debug(message)
end

defimpl Simperium.MessageDebug, for: Any do
  def debug(message), do: message
end

defimpl Simperium.MessageDebug, for: Simperium.Message.Heartbeat do
  def debug(%Simperium.Message.Heartbeat{count: count}) do
    "❤️ #{count}"
  end
end

defimpl Simperium.MessageDebug, for: Simperium.Message.BucketInit do
  def debug(_msg) do
    "🚀"
  end
end
