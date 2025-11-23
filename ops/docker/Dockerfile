FROM alpine:latest

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    curl \
    cmake \
    git \
    linux-headers \
    mesa-dev \
    libx11-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxi-dev

# Install Zig
ARG ZIG_VERSION=0.15.2
ARG ZIG_ARCH=x86_64-linux
RUN curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz" | tar -xJ -C /opt/ && \
    ln -s /opt/zig-${ZIG_ARCH}-${ZIG_VERSION}/zig /usr/local/bin/zig

ENV PATH="/opt/zig-${ZIG_ARCH}-${ZIG_VERSION}:${PATH}"

WORKDIR /app
