FROM elixir:1.9-alpine as builder

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

RUN MIX_ENV=prod mix release --path /var/release

RUN rm -fr /var/app/src/

FROM elixir:1.9-alpine

COPY --from=builder /var/release /var/release
WORKDIR /var/release
RUN mkdir -p /var/data/ingest

CMD ./bin/ingest start