defmodule Ingest.Web.Layout do
  use Phoenix.View,
    root: "lib/ingest/templates",
    namespace: Ingest

  def title do
    "Ingest Web"
  end
end
