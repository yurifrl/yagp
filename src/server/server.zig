const std = @import("std");
const SocketConf = @import("config.zig");
const Request = @import("request.zig");
const Response = @import("response.zig");
const Method = Request.Method;
const stdout = std.io.getStdOut().writer();

const ThreadContext = struct {
    server: std.net.Server,
    allocator: std.mem.Allocator,
    thread_id: usize,
};

fn handleConnection(connection: std.net.Server.Connection, thread_id: usize, allocator: std.mem.Allocator) !void {
    defer connection.stream.close();

    var buffer: [1000]u8 = undefined;
    for (0..buffer.len) |i| {
        buffer[i] = 0;
    }
    try Request.read_request(connection, buffer[0..buffer.len]);
    const request = Request.parse_request(buffer[0..buffer.len]);

    const timestamp = std.time.timestamp();
    try stdout.print("[{d}] [Thread-{d}] [{s}] {s} from {}\n", .{ timestamp, thread_id, @tagName(request.method), request.uri, connection.address });

    if (request.method == Method.GET) {
        if (std.mem.eql(u8, request.uri, "/")) {
            try Response.send_file(connection, "zig-out/htmlout/index.html", allocator);
        } else if (std.mem.eql(u8, request.uri, "/index.wasm")) {
            try Response.send_file(connection, "zig-out/htmlout/index.wasm", allocator);
        } else if (std.mem.eql(u8, request.uri, "/index.js")) {
            try Response.send_file(connection, "zig-out/htmlout/index.js", allocator);
        } else {
            try Response.send_404(connection);
        }
    }
}

fn workerFn(ctx: *ThreadContext) !void {
    while (true) {
        const connection = try ctx.server.accept();
        handleConnection(connection, ctx.thread_id, ctx.allocator) catch |err| {
            try stdout.print("[Thread-{d}] Error handling connection: {any}\n", .{ ctx.thread_id, err });
        };
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const socket = try SocketConf.Socket.init();
    try stdout.print("Server Addr: {any}\n", .{socket._address});
    const server = try socket._address.listen(.{});

    const thread_count = try std.Thread.getCpuCount();
    try stdout.print("Starting server with {d} worker threads (using all available CPU cores)\n", .{thread_count});

    var threads = try allocator.alloc(std.Thread, thread_count);
    defer allocator.free(threads);

    var contexts = try allocator.alloc(ThreadContext, thread_count);
    defer allocator.free(contexts);

    for (0..thread_count) |i| {
        contexts[i] = ThreadContext{
            .server = server,
            .allocator = allocator,
            .thread_id = i,
        };
        threads[i] = try std.Thread.spawn(.{}, workerFn, .{&contexts[i]});
    }

    for (threads) |thread| {
        thread.join();
    }
}
