defmodule Simperium.Change do
  keys = [:clientid, :cv, :id, :o, :v, :ev, :ccids]
  @enforce_keys keys
  defstruct [:sv | keys]

  @doc """
  Create remote change with the specified payload.
  """
  def create(clientid, cv, id, sv, ev, o, v, ccids) do
    %__MODULE__{
      clientid: clientid,
      cv: cv,
      id: id,
      sv: sv,
      ev: ev,
      o: o,
      v: v,
      ccids: ccids
    }
  end

  def from_json(json_map = %{"error" => error}) do
    {:ok,
     %Simperium.ChangeError{
       error: error,
       id: Map.get(json_map, "id"),
       ccids: Map.get(json_map, "ccids"),
       clientid: Map.get(json_map, "clientid")
     }}
  end

  def from_json(json_map) do
    {:ok,
     %__MODULE__{
       clientid: Map.get(json_map, "clientid"),
       cv: Map.get(json_map, "cv"),
       id: Map.get(json_map, "id"),
       sv: Map.get(json_map, "sv"),
       ev: Map.get(json_map, "ev"),
       o: Map.get(json_map, "o"),
       v: Map.get(json_map, "v"),
       ccids: Map.get(json_map, "ccids")
     }}
  end
end
