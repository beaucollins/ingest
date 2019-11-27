defmodule Simperium.Message.RemoteChanges do
  @moduledoc """
  Simperium.com sends changes in realtime or when requested via a `Message.ChangeVersion`.

      iex> ~s(0:c:[{"clientid": "sjs-2012121301-9af05b4e9a95132f614c", "id": "newobject", "o": "M", "v": {"new": {"o": "+", "v": "object"}}, "ev": 1, "cv": "511aa58737a401031d57db90", "ccids": ["3a5cbd2f0a71fca4933fff5a54d22b60"]}])
      ...> |> parse()
      {:ok, {:bucket, 0, %Message.RemoteChanges{changes: [%Simperium.Change{
        clientid: "sjs-2012121301-9af05b4e9a95132f614c",
        cv: "511aa58737a401031d57db90",
        id: "newobject",
        o: "M",
        v: %{"new" => %{"o" => "+", "v" => "object"}},
        sv: nil,
        ev: 1,
        ccids: ["3a5cbd2f0a71fca4933fff5a54d22b60"]
      }]}}}
  """
  defstruct changes: []
end
