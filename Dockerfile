FROM debian:bookworm-slim AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        bison \
        build-essential \
        ca-certificates \
        cmake \
        git \
        libbrotli-dev \
        libssl-dev \
        libtool \
        libzstd-dev \
        pkg-config \
        ruby \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

ARG H2O_COMMIT
WORKDIR /src/h2o

RUN test -n "$H2O_COMMIT" \
    && git init . \
    && git remote add origin https://github.com/h2o/h2o.git \
    && git fetch --depth=1 origin "$H2O_COMMIT" \
    && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "$H2O_COMMIT" \
    && git submodule update --init --recursive --depth=1

RUN cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DWITHOUT_LIBS=ON \
        -DWITH_MRUBY=ON \
    && cmake --build build --target h2o --parallel "$(nproc)" \
    && cmake --install build --strip

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libbrotli1 \
        libssl3 \
        libzstd1 \
        openssl \
        perl \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/www/html \
    && printf '%s\n' '<!doctype html><title>H2O</title><h1>H2O is running</h1>' > /var/www/html/index.html

COPY --from=build /usr/local/bin/h2o /usr/local/bin/h2o
COPY --from=build /usr/local/share/h2o /usr/local/share/h2o
COPY --from=build /src/h2o/LICENSE /usr/local/share/licenses/h2o/LICENSE
COPY h2o.conf /etc/h2o/h2o.conf

ARG H2O_COMMIT
LABEL org.opencontainers.image.title="H2O HTTP server" \
      org.opencontainers.image.revision="$H2O_COMMIT" \
      org.opencontainers.image.licenses="MIT"

USER 65534:65534
EXPOSE 8080
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/local/bin/h2o"]
CMD ["-c", "/etc/h2o/h2o.conf"]
