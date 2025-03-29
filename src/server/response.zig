const std = @import("std");
const Connection = std.net.Server.Connection;

fn getMimeType(path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, path, ".html")) return "text/html";
    if (std.mem.endsWith(u8, path, ".wasm")) return "application/wasm";
    return "application/octet-stream";
}

pub fn send_file(conn: Connection, path: []const u8, allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(content);

    const mime_type = getMimeType(path);
    const header = try std.fmt.allocPrint(allocator, "HTTP/1.1 200 OK\r\nContent-Length: {d}\r\nContent-Type: {s}\r\nConnection: Closed\r\n\r\n", .{ content.len, mime_type });
    defer allocator.free(header);

    try conn.stream.writeAll(header);
    try conn.stream.writeAll(content);
}

pub fn send_200(conn: Connection) !void {
    const message = ("HTTP/1.1 200 OK\nContent-Length: 48" ++ "\nContent-Type: text/html\n" ++ "Connection: Closed\n\n<html><body>" ++ "<h1>Hello, World!</h1></body></html>");
    _ = try conn.stream.write(message);
}

pub fn send_404(conn: Connection) !void {
    const message = ("HTTP/1.1 404 Not Found\nContent-Length: 50" ++ "\nContent-Type: text/html\n" ++ "Connection: Closed\n\n<html><body>" ++ "<h1>File not found!</h1></body></html>");
    _ = try conn.stream.write(message);
}
