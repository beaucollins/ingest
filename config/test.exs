use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn

config :ingest, :client, proxy: "http://localhost:5431"

config :mnesia, :dir, 'tmp/Mnesia.test'
