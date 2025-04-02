const std = @import("std");
const httpz = @import("httpz");

const mimeTypes = .{
    .{ ".html", "text/html" },
    .{ ".css", "text/css" },
    .{ ".js", "application/javascript" },
    .{ ".wasm", "application/wasm" },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // More advance cases will use a custom "Handler" instead of "void".
    // The last parameter is our handler instance, since we have a "void"
    // handler, we passed a void ({}) value.
    var server = try httpz.Server(void).init(allocator, .{ .port = 8080, .address = "0.0.0.0" }, {});
    defer {
        // clean shutdown, finishes serving any live request
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});
    router.get("/*", serveFiles, .{});

    std.debug.print("Server listening on port 8080\n", .{});
    // blocks
    try server.listen();
}

fn mimeForPath(path: []const u8) []const u8 {
    const extension = std.fs.path.extension(path);
    inline for (mimeTypes) |kv| {
        if (std.mem.eql(u8, extension, kv[0])) {
            return kv[1];
        }
    }
    return "application/octet-stream";
}

fn serveFiles(req: *httpz.Request, res: *httpz.Response) !void {
    const allocator = res.arena;
    const path = req.url.path;

    // Prevent directory traversal attacks
    if (std.mem.indexOf(u8, path, "..") != null) {
        res.status = 403;
        res.body = "Forbidden";
        return;
    }

    // Map root path to index.html
    const file_path = if (std.mem.eql(u8, path, "/"))
        try std.fmt.allocPrint(allocator, "zig-out/htmlout/index.html", .{})
    else
        try std.fmt.allocPrint(allocator, "zig-out/htmlout{s}", .{path});

    // Try to open the file
    const file = std.fs.cwd().openFile(file_path, .{}) catch {
        std.debug.print("File not found: {s}\n", .{file_path});
        res.status = 404;
        res.body = "File not found";
        return;
    };
    defer file.close();

    // Read file content
    const stat = try file.stat();
    const content = try file.readToEndAlloc(allocator, @as(usize, @intCast(stat.size)));

    // Set content type based on file extension
    const content_type = mimeForPath(file_path);
    res.header("Content-Type", content_type);

    std.debug.print("Serving file: {s} ({d} bytes)\n", .{ file_path, content.len });
    res.status = 200;
    res.body = content;
}
