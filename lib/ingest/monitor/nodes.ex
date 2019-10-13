defmodule Ingest.Monitor.Nodes do
  @derive Jason.Encoder
  defstruct current: Node.self(), nodes: Node.list([:this, :connected])

  def status() do
    %Ingest.Monitor.Nodes{}
  end
end
