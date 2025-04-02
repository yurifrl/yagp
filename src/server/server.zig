const std = @import("std");
const zap = @import("zap");

const allowed_ext = [_][]const u8{ ".html", ".js", ".wasm", ".yaml" };

fn on_request(r: zap.Request) anyerror!void {
    if (r.path == null) {
        try r.sendBody("<html><body><h1>Hello from ZAP!!!</h1></body></html>");
        return;
    }

    const the_path = r.path.?;
    std.debug.print("PATH: {s}\n", .{the_path});

    var path_to_serve: []const u8 = the_path;
    if (std.mem.eql(u8, the_path, "/")) {
        path_to_serve = "/index.html";
    }

    const allocator = std.heap.page_allocator;
    const full_path = try std.fmt.allocPrint(allocator, "zig-out/htmlout{s}", .{path_to_serve});
    defer allocator.free(full_path);

    var is_allowed = false;
    for (allowed_ext) |ext| {
        if (std.mem.endsWith(u8, path_to_serve, ext)) {
            is_allowed = true;
            break;
        }
    }

    if (!is_allowed) {
        r.setStatus(.forbidden);
        try r.sendBody("File type not allowed");
        return;
    }

    var file = std.fs.cwd().openFile(full_path, .{}) catch |err| {
        std.debug.print("Error opening file: {}\n", .{err});
        r.setStatus(.not_found);
        try r.sendBody("File not found");
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const contents = try allocator.alloc(u8, file_size);
    defer allocator.free(contents);

    // Set content type based on file extension
    if (std.mem.endsWith(u8, path_to_serve, ".html")) {
        try r.setHeader("Content-Type", "text/html");
    } else if (std.mem.endsWith(u8, path_to_serve, ".js")) {
        try r.setHeader("Content-Type", "application/javascript");
    } else if (std.mem.endsWith(u8, path_to_serve, ".wasm")) {
        try r.setHeader("Content-Type", "application/wasm");
    }

    _ = try file.readAll(contents);
    try r.sendBody(contents);
}

pub fn main() !void {
    var listener = zap.HttpListener.init(.{
        .port = 8080,
        .on_request = on_request,
        .log = true,
    });
    try listener.listen();

    std.debug.print("Listening on 0.0.0.0:8080\n", .{});

    // start worker threads
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
