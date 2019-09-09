FROM elixir:1.9-alpine

RUN mix local.hex --force;\
	mix local.rebar --force;

COPY mix.* /var/app/src/
WORKDIR /var/app/src

RUN mix deps.get; mix deps.compile;

COPY lib /var/app/src/lib
COPY config /var/app/src/config
COPY test /var/apps/src/test
COPY priv /var/apps/src/priv

RUN mix release --path /var/app/app
RUN rm -fr /var/app/src

CMD /var/app/app/bin/ingest start