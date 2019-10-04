FROM elixir:1.9-alpine

RUN apk add --no-cache bash;\
	mix local.hex --force;\
	mix local.rebar --force;

COPY mix.* /var/app/src/
WORKDIR /var/app/src

ENV MIX_ENV=prod

RUN mix deps.get; mix deps.compile;

COPY lib lib
COPY config config
COPY priv priv
COPY test test
COPY rel rel

RUN mkdir -p /usr/local/bin

RUN mix release --path /var/release

RUN rm -fr /var/app/src/
RUN mkdir -p /var/data/ingest
COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD /var/release/bin/ingest start