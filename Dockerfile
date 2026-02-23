# ---------------------------------------------------------------------------
# Build stage
# ---------------------------------------------------------------------------
ARG ELIXIR_VERSION=1.18.2
ARG OTP_VERSION=27.2
ARG DEBIAN_VERSION=bookworm-20250113-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS build

RUN apt-get update -y \
  && apt-get install -y build-essential git \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Install deps first (layer-cached unless mix.exs / mix.lock change)
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# Copy compile-time config before compiling deps so config changes
# that affect deps trigger a recompile.
RUN mkdir config
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Compile app first — this generates the phoenix-colocated hooks module
# that esbuild resolves from the build path via NODE_PATH.
RUN mix compile

# Build and digest static assets
RUN mix assets.deploy

# runtime.exs is read at boot, not compile time — copy last so changes
# to it don't invalidate the compile cache.
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# ---------------------------------------------------------------------------
# Runtime stage — minimal image, just the compiled release
# ---------------------------------------------------------------------------
FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
  && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# UTF-8 locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV=prod

COPY --from=build --chown=nobody:root /app/_build/prod/rel/maze ./

USER nobody

EXPOSE 4000

CMD ["/app/bin/server"]
