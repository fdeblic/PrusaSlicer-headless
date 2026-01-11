# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    autoconf \
    automake \
    cmake \
    libglu1-mesa-dev \
    libdbus-1-dev \
    libtool \
    texinfo \
    locales \
    ca-certificates \
    zlib1g-dev \
    python3 \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

ARG PRUSA_SLICER_VERSION=2.9.4
RUN git clone --depth 1 --branch version_${PRUSA_SLICER_VERSION} https://github.com/prusa3d/PrusaSlicer

WORKDIR /PrusaSlicer/deps/build
RUN cmake .. -DPrusaSlicer_deps_PACKAGE_EXCLUDES="wxWidgets" -DDEP_DEBUG=OFF
RUN --mount=type=cache,target=/PrusaSlicer/deps/build,sharing=locked \
    --mount=type=cache,target=/root/.cache \
    make -j$(nproc)

WORKDIR /PrusaSlicer/build
RUN cmake .. \
    -DSLIC3R_STATIC=ON \
    -DSLIC3R_GUI=OFF \
    -DSLIC3R_BUILD_TESTS=OFF \
    -DCMAKE_PREFIX_PATH=$(pwd)/../deps/build/destdir/usr/local
RUN --mount=type=cache,target=/PrusaSlicer/build,sharing=locked \
    --mount=type=cache,target=/root/.cache \
    make -j$(nproc)



FROM debian:bookworm-slim AS runner

RUN apt-get update && apt-get install -y \
    libpng16-16 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /PrusaSlicer/build/src/prusa-slicer /usr/local/bin
COPY --from=builder /PrusaSlicer/resources /usr/local/share/PrusaSlicer/resources

WORKDIR /workspace

RUN adduser prusa
USER prusa

ENTRYPOINT ["/usr/local/bin/prusa-slicer"]
CMD ["--help"]