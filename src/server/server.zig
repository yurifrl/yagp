const std = @import("std");
const SocketConf = @import("config.zig");
const Request = @import("request.zig");
const Response = @import("response.zig");
const Method = Request.Method;
const stdout = std.io.getStdOut().writer();
const options = @import("build_options");
const posix = std.posix;
const os = std.os;
const shared_config = @import("shared_config");
const config = shared_config.Config.init();
const out_dir = "zig-out/htmlout";
const allowed_ext = [_][]const u8{ ".html", ".js", ".wasm" };
// This is dead code, I plan to use it to kill the thread, but I dont know how to call this in sigini
var running = std.atomic.Value(bool).init(true);

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
        const path = if (std.mem.eql(u8, request.uri, "/")) "index.html" else request.uri[1..];
        for (allowed_ext) |ext| {
            if (std.mem.endsWith(u8, path, ext)) {
                try Response.send_file(connection, try std.fmt.allocPrint(allocator, "{s}/{s}", .{ out_dir, path }), allocator);
                return;
            }
        }
        try Response.send_404(connection);
    }
}

fn workerFn(ctx: *ThreadContext) !void {
    while (running.load(.monotonic)) {
        const connection = try ctx.server.accept();
        handleConnection(connection, ctx.thread_id, ctx.allocator) catch |err| {
            try stdout.print("[Thread-{d}] Error handling connection: {any}\n", .{ ctx.thread_id, err });
        };
    }
}

pub fn sig_handler(sig: i32) callconv(.C) void {
    std.debug.print("Caught signal: {}\n", .{sig});
    running.store(false, .monotonic);
    std.process.exit(0);
}
pub fn main() !void {
    // Manage the Ctrl + C
    const act = os.linux.Sigaction{
        .handler = .{ .handler = sig_handler },
        .mask = os.linux.empty_sigset,
        .flags = 0,
    };
    if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
        return error.SignalHandlerError;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const socket = try SocketConf.Socket.init();
    try stdout.print("Server Addr: {any}\n", .{socket._address});
    const server = try socket._address.listen(.{});

    // const thread_count = try std.Thread.getCpuCount();
    const thread_count = 1;
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
