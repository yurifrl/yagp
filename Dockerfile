FROM alpine:latest AS zig-installer
ARG TARGETARCH
RUN apk add --no-cache wget \
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

FROM alpine:latest AS dev
COPY --from=zig-installer /usr/local/zig /usr/local/zig
ENV PATH="/usr/local/zig:${PATH}"
WORKDIR /app

FROM dev AS builder
COPY . .
RUN zig build

FROM scratch
WORKDIR /app
COPY --from=builder /app/zig-out/bin/game.wasm ./zig-out/bin/game.wasm
COPY --from=builder /app/zig-out/bin/server ./server
COPY --from=builder /app/index.html ./

EXPOSE 8080
CMD ["./server"]