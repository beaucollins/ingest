FROM elixir

COPY . /var/app
WORKDIR /var/app

RUN mix local.hex --force;\
	mix local.rebar --force;\
	mix deps.get;\
	mix release;

CMD /var/app/_build/dev/rel/ingest/bin/ingest start