const std = @import("std");
const Connection = std.net.Server.Connection;

fn getMimeType(path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, path, ".html")) return "text/html";
    if (std.mem.endsWith(u8, path, ".wasm")) return "application/wasm";
    if (std.mem.endsWith(u8, path, ".js")) return "application/javascript";
    return "application/octet-stream";
}

pub fn send_file(conn: Connection, path: []const u8, allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const max_size: usize = @intCast(stat.size);
    const content = try file.readToEndAlloc(allocator, max_size);
    defer allocator.free(content);

    const mime_type = getMimeType(path);
    const header = try std.fmt.allocPrint(allocator, "HTTP/1.1 200 OK\r\nContent-Length: {d}\r\nContent-Type: {s}\r\nConnection: close\r\n\r\n", .{ content.len, mime_type });
    defer allocator.free(header);

    try conn.stream.writeAll(header);
    try conn.stream.writeAll(content);
}

pub fn send_404(conn: Connection) !void {
    const body = "<html><body><h1>File not found!</h1></body></html>";
    const message = try std.fmt.allocPrint(std.heap.page_allocator, "HTTP/1.1 404 Not Found\r\nContent-Length: {d}\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n{s}", .{ body.len, body });
    defer std.heap.page_allocator.free(message);
    _ = try conn.stream.write(message);
}
