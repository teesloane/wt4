ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3.3
ARG UBUNTU_VERSION=noble-20260217

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}"
ARG RUNNER_IMAGE="ubuntu:${UBUNTU_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    libvips-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Fetch deps first (cached unless mix files change)
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# Compile deps (cached unless config changes)
COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

# Compile app (generates phoenix-colocated JS into _build before assets.deploy needs it)
COPY priv priv
COPY lib lib
RUN mix compile

# Build assets
COPY assets assets
RUN mix assets.deploy

RUN mix release

# --- Runtime image ---
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y \
    libvips42t64 \
    libssl3t64 \
    libncurses6 \
    locales \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/weakty ./
COPY entrypoint.sh /app/bin/entrypoint.sh
RUN chmod +x /app/bin/entrypoint.sh

ENV HOME=/app
ENV PHX_SERVER=true

EXPOSE 4000

ENTRYPOINT ["/app/bin/entrypoint.sh"]
