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

FROM ubuntu:latest AS dev
WORKDIR /app
COPY --from=zig-installer /usr/local/zig /usr/local/zig
ENV PATH="/usr/local/zig:${PATH}"

RUN apt-get update \
    && apt-get install git cmake clang build-essential ca-certificates python3 -y --no-install-recommends

# RUN apt-get update && apt-get install -y git python3 cmake build-essential

RUN git clone https://github.com/emscripten-core/emsdk.git /emsdk
RUN cd /emsdk \
    && ./emsdk install latest \
    && ./emsdk activate latest

# RUN apt-get install -y libx11-dev libxrender-dev libxext-dev
# RUN apt-get install -y libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libxfixes-dev
# RUN apt-get install -y wayland-protocols libwayland-dev
# RUN apt-get install -y libgl1-mesa-dev libglx-dev
# RUN apt-get install -y libxkbcommon-dev

ENV EMSDK="/emsdk"
ENV PATH="/emsdk/upstream/emscripten:/emsdk/node/20.18.0_64bit/bin:${PATH}"

# RUN . /emsdk/emsdk_env.sh

FROM dev AS builder
COPY . .
# RUN . /app/emsdk/emsdk_env.sh && zig build
RUN emsdk list
RUN . /emsdk/emsdk_env.sh && zig build -Dtarget=wasm32-emscripten

FROM scratch
WORKDIR /app
COPY --from=builder /app /app

EXPOSE 8080
CMD ["./server"]