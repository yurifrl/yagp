###################################################################################
# Zig Installer Layer
###################################################################################
FROM ubuntu:latest AS zig-installer
ARG TARGETARCH
RUN apt-get update && apt-get install -y wget xz-utils \
    && if [ "$TARGETARCH" = "arm64" ]; then \
       wget https://ziglang.org/download/0.14.0/zig-linux-aarch64-0.14.0.tar.xz \
       && tar -xf zig-linux-aarch64-0.14.0.tar.xz \
       && mv zig-linux-aarch64-0.14.0 /usr/local/zig; \
    elif [ "$TARGETARCH" = "arm" ]; then \
       wget https://ziglang.org/download/0.14.0/zig-linux-armv7a-0.14.0.tar.xz \
       && tar -xf zig-linux-armv7a-0.14.0.tar.xz \
       && mv zig-linux-armv7a-0.14.0 /usr/local/zig; \
    else \
       wget https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz \
       && tar -xf zig-linux-x86_64-0.14.0.tar.xz \
       && mv zig-linux-x86_64-0.14.0 /usr/local/zig; \
    fi

###################################################################################
# Base Layer
# Some of those are required to build emsdk and some are used in runtime, not sure which is which, dont want to find out
###################################################################################
FROM ubuntu:latest AS base
RUN apt-get update && apt-get install -y --no-install-recommends git python3 cmake build-essential ca-certificates

###################################################################################
# Emscripten Layer
###################################################################################
FROM base AS emsdk
WORKDIR /emsdk
RUN git clone https://github.com/emscripten-core/emsdk.git .
RUN ./emsdk install latest
RUN ./emsdk activate latest

###################################################################################
# Dev Layer, The image that has it all, it is also user by the builder layer
###################################################################################
FROM base AS dev
COPY --from=zig-installer /usr/local/zig /usr/local/zig
COPY --from=emsdk /emsdk /emsdk

# big packages required by raylib
RUN apt-get install -y libx11-dev libxrender-dev libxext-dev
RUN apt-get install -y libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libxfixes-dev
RUN apt-get install -y wayland-protocols libwayland-dev
RUN apt-get install -y libgl1-mesa-dev libglx-dev
RUN apt-get install -y libxkbcommon-dev

ENV EMSDK="/emsdk"
ENV PATH="/emsdk/upstream/emscripten:/emsdk/node/20.18.0_64bit/bin:${PATH}"
ENV PATH="/usr/local/zig:${PATH}"

WORKDIR /app

###################################################################################
# Builder Layer
###################################################################################
FROM dev AS builder
COPY . .
RUN rm -rf ~/.cache/zig
RUN zig build -Dtarget=wasm32-emscripten --sysroot /emsdk/upstream/emscripten
RUN zig build

###################################################################################
# Runner Layer
###################################################################################
FROM scratch
WORKDIR /app
COPY --from=builder /app/zig-out /app/zig-out

EXPOSE 8080
CMD ["zig-out/bin/server"]