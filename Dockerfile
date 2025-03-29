FROM alpine:latest AS zig-installer
RUN apk add --no-cache wget \
    && wget https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz \
    && tar -xf zig-linux-x86_64-0.14.0.tar.xz \
    && mv zig-linux-x86_64-0.14.0 /usr/local/zig

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