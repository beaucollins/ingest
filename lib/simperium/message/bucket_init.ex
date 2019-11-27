defmodule Simperium.Message.BucketInit do
  @moduledoc """
  Sent by a `Simperium.Client` to start syncing a Simperium bucket.

  See [`init`](https://github.com/Simperium/simperium-protocol/blob/master/SYNCING.md#authorizing-init).
  """

  @enforce_keys [:clientid, :app_id, :name, :token]
  defstruct [
    # Represents a unique instance of a client.
    :clientid,
    # Simperium.com Application ID
    :app_id,
    # Bucket name
    :name,
    # Authorization token from simperium.com
    :token,
    # [Optional] command issued by simperium.com on successful init.
    :cmd,
    # The client library being used
    library: "simperium-ex",
    # The client's version
    version: "1.0.0",
    # Simperium.com API version to use
    api: 1
  ]
end
