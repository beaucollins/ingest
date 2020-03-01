use Mix.Config

config :mnesia, :dir, '/var/data/ingest/Mnesia.ingest'

config :libcluster,
  topologies: [
    k8s: [
      strategy: Elixir.Cluster.Strategy.Kubernetes.DNSSRV,
      config: [
        service: "ingest-cluster",
        application_name: "ingest",
        namespace: "default"
      ]
    ]
  ]
