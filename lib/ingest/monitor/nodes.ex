defmodule Ingest.Monitor.Nodes do
  @derive Jason.Encoder
  defstruct [:nodes, current: Node.self()]

  def status() do
    %Ingest.Monitor.Nodes{nodes: Node.list([:this, :connected]), current: Node.self()}
  end
end
