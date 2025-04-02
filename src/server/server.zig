const std = @import("std");
const net = std.net;
const http = std.http;

pub fn Server(comptime Context: type) type {
    return struct {
        server: net.Server,
        context: Context,
        address: net.Address,

        const Self = @This();

        pub fn init(address: net.Address, context: Context) !Self {
            const server = try address.listen(.{});
            return Self{
                .server = server,
                .context = context,
                .address = address,
            };
        }

        pub fn deinit(self: *Self) void {
            self.server.deinit();
        }

        pub fn start(self: *Self, handle_request_fn: *const fn (*http.Server.Request, Context) anyerror!void) void {
            while (true) {
                var connection = self.server.accept() catch |err| {
                    std.debug.print("Connection to client interrupted: {}\n", .{err});
                    continue;
                };
                defer connection.stream.close();

                var read_buffer: [1024]u8 = undefined;
                var http_server = http.Server.init(connection, &read_buffer);

                var request = http_server.receiveHead() catch |err| {
                    std.debug.print("Could not read head: {}\n", .{err});
                    continue;
                };

                handle_request_fn(&request, self.context) catch |err| {
                    std.debug.print("Could not handle request: {}\n", .{err});
                    continue;
                };
            }
        }
    };
}

// Example handler for requests
fn defaultRequestHandler(request: *http.Server.Request, _: void) !void {
    const target = request.head.target;
    std.debug.print("Handling request for {s}\n", .{target});

    // Get file path from target
    const allocator = std.heap.page_allocator;
    const file_target = if (std.mem.eql(u8, target, "/")) "/index.html" else target;
    const file_path = try std.fmt.allocPrint(allocator, "zig-out/htmlout{s}", .{file_target});
    defer allocator.free(file_path);

    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try request.respond("File not found\n", .{ .status = .not_found });
            return;
        }
        return err;
    };
    defer file.close();

    const stat = try file.stat();
    const contents = try allocator.alloc(u8, @intCast(stat.size));
    defer allocator.free(contents);

    _ = try file.readAll(contents);
    try request.respond(contents, .{});
}

pub fn main() !void {
    const addr = try net.Address.parseIp4("127.0.0.1", 8080);
    var server = try Server(void).init(addr, {});
    defer server.deinit();

    std.debug.print("Server listening on {}\n", .{addr});
    server.start(&defaultRequestHandler);
}
